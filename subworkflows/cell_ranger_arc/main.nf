
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { count }              from '../../modules/cell_ranger_arc/count'
include { make_libraries_csv } from '../../modules/cell_ranger_arc/make_libraries_csv'
include { mkref }              from '../../modules/cell_ranger_arc/mkref'

include { merge_yaml as merge_software_versions } from '../../modules/yq/merge_yaml'

include { concat_workflow_emissions } from '../../modules/utilities/concat_workflow_emissions'
include { get_feature_types }         from '../../modules/utilities/get_feature_types'
include { make_map }                  from '../../modules/utilities/make_map'

include { print_as_json }             from '../../modules/utilities/print_as_json'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow cell_ranger_arc {

	take:
		filtered_stage_parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// create missing cell ranger arc indexes
		// -------------------------------------------------------------------------------------------------

		// filter the parameter sets for missing `index path` keys, then take the unique genome parameter sets
		missing_genome_indexes = filtered_stage_parameters
			.findAll{!it.containsKey('index path')}
			.collect{it.get('genome parameters')}
			.unique()

		// make channels of parameters for genomes that need indexes to be created
		unique_identifiers  = channel.fromList(missing_genome_indexes.collect{x -> x.get('unique id')})
		tags                = channel.fromList(missing_genome_indexes.collect{x -> x.get('genome')})
		organisms           = channel.fromList(missing_genome_indexes.collect{x -> x.get('organism')})
		assemblies          = channel.fromList(missing_genome_indexes.collect{x -> x.get('assembly')})
		non_nuclear_contigs = channel.fromList(missing_genome_indexes.collect{x -> x.get('non-nuclear contigs')})
		motifs              = channel.fromList(missing_genome_indexes.collect{x -> x.get('motifs')})
		path_to_fastas      = channel.fromList(missing_genome_indexes.collect{x -> x.get('fasta files')})
		path_to_gtfs        = channel.fromList(missing_genome_indexes.collect{x -> x.get('gtf files')})

		// create cell ranger arc indexes
		mkref(unique_identifiers, tags, organisms, assemblies, non_nuclear_contigs, motifs, path_to_fastas, path_to_gtfs)

		// make a channel of newly created genome indexes, each defined in a map
		mkref.out.uid
			.merge(mkref.out.path)
			.map{x -> make_map(x, ['uid','index path'])}
			.dump(tag: 'cell_ranger_arc:new_genome_indexes', pretty: true)
			.set{new_genome_indexes}

		// -------------------------------------------------------------------------------------------------
		// make a sample sheet for all samples that need to be quantified in some dataset
		// -- TODO: this process should only run once in this workflow. add a check to ensure that?
		// -------------------------------------------------------------------------------------------------

		// get the feature types from params
		feature_type_params = get_feature_types()

		// make channels to create the libraries csv file that cell ranger arc count expects
		fastq_paths       = channel.from(filtered_stage_parameters.collect{x -> x.get('fastq paths')}.flatten().unique()).collect()
		fastq_files_regex = channel.value('(.*)_S[0-9]+_L[0-9]+_R1_001.fastq.gz')
		samples           = channel.value(feature_type_params.collect{x -> x.get('sample name')})
		feature_types     = channel.value(feature_type_params.collect{x -> x.get('feature type')})

		make_libraries_csv(fastq_paths, fastq_files_regex, samples, feature_types)

		// -------------------------------------------------------------------------------------------------
		// get parameter sets for cell ranger arc datasets
		// -------------------------------------------------------------------------------------------------

		// branch datasets into two channels: {missing,provided} according to the presence of the 'index path' key
		channel
			.fromList(filtered_stage_parameters)
			.branch({
				def index_provided = it.containsKey('index path')
				missing: index_provided == false
				provided: index_provided == true})
			.set{datasets_with_index_paths}

		datasets_with_index_paths.missing.dump(tag: 'cell_ranger_arc:datasets_with_index_paths.missing', pretty: true)
		datasets_with_index_paths.provided.dump(tag: 'cell_ranger_arc:datasets_with_index_paths.provided', pretty: true)

		// update the index path for datasets missing the key using the newly available genomes and branch into missing and provided quantification using the 'quantification path' key
		datasets_with_index_paths.missing
			.combine(new_genome_indexes)
			.filter{it.first().get('genome parameters').get('unique id') == it.last().get('uid')}
			.map{it.first() + it.last().subMap('index path')}
			.concat(datasets_with_index_paths.provided)
			.branch({
				def quantification_provided = it.containsKey('quantification path')
				missing: quantification_provided == false
				provided: quantification_provided == true})
			.set{datasets_to_quantify}

		datasets_to_quantify.missing.dump(tag: 'cell_ranger_arc:datasets_to_quantify.missing', pretty: true)
		datasets_to_quantify.provided.dump(tag: 'cell_ranger_arc:datasets_to_quantify.provided', pretty: true)

		// -------------------------------------------------------------------------------------------------
		// get paths to quantification results, creating missing results as required
		// -------------------------------------------------------------------------------------------------

		// make channels of parameters for samples that need to be quantified
		unique_identifiers   = datasets_to_quantify.missing.map{it.get('unique id')}
		tags                 = datasets_to_quantify.missing.map{it.get('dataset name')}
		dataset_directories  = datasets_to_quantify.missing.map{it.get('dataset dir')}
		samples              = datasets_to_quantify.missing.map{it.get('samples')}
		additional_arguments = datasets_to_quantify.missing.map{it.get('additional arguments', '')}
		index_paths          = datasets_to_quantify.missing.map{it.get('index path')}
		sample_sheet_file    = make_libraries_csv.out.path

		count(unique_identifiers, tags, dataset_directories, samples, additional_arguments, index_paths, sample_sheet_file)

		// make a channel of newly quantified datasets, each defined in a map
		count.out.uid
			.merge(count.out.quantification_path)
			.map{x -> make_map(x, ['uid','quantification path'])}
			.dump(tag: 'cell_ranger_arc:new_quantified_datasets', pretty: true)
			.set{new_quantified_datasets}

		// add quantified paths to the filtered parameters for a complete set of parameters for this subworkflow
		datasets_to_quantify.missing
			.combine(new_quantified_datasets)
			.filter{it.first().get('unique id') == it.last().get('uid')}
			.map{it.first() + it.last().subMap('quantification path')}
			.concat(datasets_to_quantify.provided)
			.dump(tag: 'cell_ranger_arc:quantified_datasets', pretty: true)
			.set{quantified_datasets}

		// -------------------------------------------------------------------------------------------------
		// make summary report for cell ranger arc stage
		// -------------------------------------------------------------------------------------------------

		// collate the software version yaml files into one
		concat_workflow_emissions([mkref, count], 'versions')
			.collect()
			.set{versions}

		merge_software_versions(versions)

		// render a report

	emit:
		subworkflows         = quantified_datasets.count().flatMap{['cell ranger arc'].multiply(it)}
		unique_ids           = quantified_datasets.flatMap{it.get('unique id')}
		stage_names          = quantified_datasets.flatMap{it.get('stage name')}
		dataset_names        = quantified_datasets.flatMap{it.get('dataset name')}
		index_paths          = quantified_datasets.flatMap{it.get('index path')}
		quantification_paths = quantified_datasets.flatMap{it.get('quantification path')}
		report               = channel.of('report.document')
}
