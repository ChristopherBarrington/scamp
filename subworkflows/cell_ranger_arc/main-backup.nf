
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { mkref } from '../../modules/cell_ranger_arc/mkref'
include { make_libraries_csv } from '../../modules/cell_ranger_arc/make_libraries_csv'
include { count } from '../../modules/cell_ranger_arc/count'

include { merge_yaml as merge_software_versions } from '../../modules/yq/merge_yaml'

include { add_parameter_sets ;
          check_for_matching_key_values ;
          concat_workflow_emissions ;
          concatenate_maps_list ;
          get_feature_types ;
          make_map ;
          print_as_json ;
          rename_map_keys ;
          val_to_path } from '../../modules/utilities'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow cell_ranger_arc {

	take:
		filtered_stage_parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// get paths to genome indexes, creating missing indices as required
		// -------------------------------------------------------------------------------------------------

		// branch genomes into two channels: {missing,provided} according to presence of the 'index path' key
		channel
			.fromList(filtered_stage_parameters.collect{add_parameter_sets(it.get('genome parameters'), ['index path':it.get('index path', null)])})
			.unique()
			.dump(tag:'cell_ranger_arc:genomes', pretty:true)
			.branch({
				def index_path_missing = it.get('index path')==null
				missing: index_path_missing == true
				provided: index_path_missing == false})
			.set{genomes}

		genomes.missing.dump(tag: 'cell_ranger_arc:genomes.missing', pretty: true)
		genomes.provided.dump(tag: 'cell_ranger_arc:genomes.provided', pretty: true)

		// make channels of parameters for genomes that need indexes to be created
		unique_identifiers  = genomes.missing.map{x -> x.get('unique id')}
		genome_names        = genomes.missing.map{x -> x.get('genome')}
		organisms           = genomes.missing.map{x -> x.get('organism')}
		assemblies          = genomes.missing.map{x -> x.get('assembly')}
		non_nuclear_contigs = genomes.missing.map{x -> x.get('non-nuclear contigs')}
		motifs              = genomes.missing.map{x -> x.get('motifs')}.map{x -> val_to_path(x)}
		path_to_fastas      = genomes.missing.map{x -> x.get('fasta files')}.map{x -> val_to_path(x)}
		path_to_gtfs        = genomes.missing.map{x -> x.get('gtf files')}.map{x -> val_to_path(x)}

		// create cell ranger arc indexes
		mkref(unique_identifiers, genome_names, organisms, assemblies, non_nuclear_contigs, motifs, path_to_fastas, path_to_gtfs)

		// make a channel of genome (names) and paths against which datasets can be quantified
		available_genome_indexes = genomes.provided
			.flatMap{x -> [x.subMap(['unique id', 'index path']).values().flatten()]}
			.concat(mkref.out.uid.merge(mkref.out.path))
			.map{ x -> make_map(x, ['unique id','index path']) }
			.dump(tag: 'cell_ranger_arc:available_genome_indexes', pretty: true)

		mkref.out.uid
			.merge(mkref.out.path)
			.map{ x -> make_map(x, ['unique id','index path']) }
			.dump(tag: 'cell_ranger_arc:new_genome_indexes', pretty: true)
			.set{new_genome_indexes}

		// -------------------------------------------------------------------------------------------------
		// make a sample sheet for all samples that need to be quantified in some dataset
		// -- TODO: this process should only run once in this workflow. add a check to ensure that?
		// -------------------------------------------------------------------------------------------------

		// get the feature types from params
		feature_type_params = get_feature_types()

		// make channels to create the libraries csv file that cell ranger arc count expects
		fastq_paths       = channel.fromPath(filtered_stage_parameters.collect{x -> x.get('fastq paths')}.flatten().unique()).collect()
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
			.dump(tag: 'cell_ranger_arc:datasets_with_index_paths', pretty: true)
			.branch({
				def index_provided = it.containsKey('index path')
				missing: index_provided == false
				provided: index_provided == true})
			.set{datasets_with_index_paths}

		datasets_with_index_paths.missing.dump(tag: 'cell_ranger_arc:datasets_with_index_paths.missing', pretty: true)
		datasets_with_index_paths.provided.dump(tag: 'cell_ranger_arc:datasets_with_index_paths.provided', pretty: true)

		// update the index path for datasets missing the key using the newly available genomes

		datasets_with_index_paths.missing
			.combine(new_genome_indexes)
			.take(1).dump(tag: 'cell_ranger_arc:datasets_with_indexes-A', pretty: true)
			.filter{it.first().get('genome parameters').get('unique id') == it.last().get('unique id')}
			// .concat(datasets_with_index_paths.provided)
			// .map{it.first() + it.last().subMap('index path')}
			// .take(1).dump(tag: 'cell_ranger_arc:datasets_with_indexes-B', pretty: true)
			.set{datasets_with_indexes}

		// branch datasets into two channels: {missing,provided} according to presence of the 'quantification path' key
		channel
			.fromList(filtered_stage_parameters)
			.combine(available_genome_indexes)
			.filter{it.first().get('genome parameters').get('unique id') == it.last().get('unique id')}
			.map{it.first() + it.last().subMap('index path')}
			.dump(tag: 'cell_ranger_arc:datasets_to_quantify', pretty: true)
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
		unique_identifiers      = datasets_to_quantify.missing.map{it.get('unique id')}
		dataset_names           = datasets_to_quantify.missing.map{it.get('dataset name')}
		dataset_directories     = datasets_to_quantify.missing.map{it.get('dataset dir')}
		samples                 = datasets_to_quantify.missing.map{it.get('samples')}
		additional_arguments    = datasets_to_quantify.missing.map{it.get('additional arguments', '')}
		index_paths             = datasets_to_quantify.missing.map{it.get('index path')}.map{val_to_path(it)}
		sample_sheet_file       = make_libraries_csv.out.path

		count(unique_identifiers, dataset_names, dataset_directories, samples, additional_arguments, index_paths, sample_sheet_file)

		// add quantified paths to the filtered parameters for a complete set of parameters for this subworkflow
		datasets_to_quantify.provided
			.flatMap{x -> [x.subMap(['unique id', 'quantification path', 'index path']).values().flatten()]}
			.concat(count.out.uid.merge(count.out.index_path).merge(count.out.quantification_path))
			.map{ x -> make_map(x, ['unique id', 'index path','quantification path']) }
			.combine(filtered_stage_parameters)
			.filter{check_for_matching_key_values(it, 'unique id')}
			.map{concatenate_maps_list(it.reverse())}
			.dump(tag: 'cell_ranger_arc:quantified_datasets', pretty: true)
			.set{quantified_datasets}

		// -------------------------------------------------------------------------------------------------
		// make summary report for cell ranger arc stage
		// -------------------------------------------------------------------------------------------------

		// collate the software version yaml files into one
		software_versions = concat_workflow_emissions([mkref, count], 'software_versions').collect()

		merge_software_versions(software_versions)

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
