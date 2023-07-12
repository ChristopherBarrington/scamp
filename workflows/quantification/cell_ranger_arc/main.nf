
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { count }              from '../../../modules/cell_ranger_arc/count'
include { make_libraries_csv } from '../../../modules/cell_ranger_arc/make_libraries_csv'
include { mkref }              from '../../../modules/cell_ranger_arc/mkref'

include { check_for_matching_key_values }     from '../../../utilities/check_for_matching_key_values'
include { concat_workflow_emissions }         from '../../../utilities/concat_workflow_emissions'
include { merge_metadata_and_process_output } from '../../../utilities/merge_metadata_and_process_output'
include { merge_process_emissions }           from '../../../utilities/merge_process_emissions'
include { rename_map_keys }                   from '../../../utilities/rename_map_keys'

include { merge_yaml as merge_software_versions } from '../../../modules/yq/merge_yaml'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow cell_ranger_arc {

	take:
		parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// create missing cell ranger arc indexes
		// -------------------------------------------------------------------------------------------------

		// branch parameters into two channels: {missing,provided} according to the presence of the 'index path' key
		parameters
			.map{it.get('genome parameters').subMap(['key', 'organism', 'assembly', 'non-nuclear contigs', 'motifs', 'fasta files', 'gtf files']) + it.subMap('index path')}
			.unique()
			.branch{
				def index_provided = it.containsKey('index path')
				provided: index_provided == true
				missing: index_provided == false}
			.set{genome_indexes}

		genome_indexes.missing.dump(tag: 'quantification:cell_ranger_arc:genome_indexes.missing', pretty: true)
		genome_indexes.provided.dump(tag: 'quantification:cell_ranger_arc:genome_indexes.provided', pretty: true)

		// make channels of parameters for genomes that need indexes to be created
		tags                = genome_indexes.missing.map{it.get('key')}
		organisms           = genome_indexes.missing.map{it.get('organism')}
		assemblies          = genome_indexes.missing.map{it.get('assembly')}
		non_nuclear_contigs = genome_indexes.missing.map{it.get('non-nuclear contigs')}
		motifs              = genome_indexes.missing.map{it.get('motifs')}
		paths_to_fastas     = genome_indexes.missing.map{it.get('fasta files')}
		paths_to_gtfs       = genome_indexes.missing.map{it.get('gtf files')}

		// create cell ranger arc indexes
		mkref(genome_indexes.missing, tags, organisms, assemblies, non_nuclear_contigs, motifs, paths_to_fastas, paths_to_gtfs)

		// make a channel of newly created genome indexes, each defined in a map
		merge_process_emissions(mkref, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'index path')}
			.map{merge_metadata_and_process_output(it)}
			.concat(genome_indexes.provided)
			.dump(tag: 'quantification:cell_ranger_arc:index_paths', pretty: true)
			.set{index_paths}

		// -------------------------------------------------------------------------------------------------
		// make a sample sheet of all samples in any dataset that should be quantified
		// -------------------------------------------------------------------------------------------------

		// when there is at least one dataset to quantify, prepare a channel to create the sample sheet
		parameters
			.map{it.subMap(['fastq paths', 'feature types'])}
			.unique()
			.map{it + ['sample_names': it.get('feature types').values().flatten()]}
			.map{it + ['feature_types': it.get('feature types').collect{k,v -> [k]*v.size()}.flatten()]}
			.map{it + [fastq_files_regex: '(.*)_S[0-9]+_L[0-9]+_R1_001.fastq.gz']}
			.map{it.findAll{it.key!='feature types'}}
			.first()
			.dump(tag: 'quantification:cell_ranger_arc:feature_type_params', pretty: true)
			.set{feature_type_params}

		// make channels to create the libraries csv file that cell ranger arc count expects
		fastq_paths       = feature_type_params.map{it.get('fastq paths')}
		fastq_files_regex = feature_type_params.map{it.get('fastq_files_regex')}
		samples           = feature_type_params.map{it.get('sample_names')}
		feature_types     = feature_type_params.map{it.get('feature_types')}

		// make a sample sheet for the whole project which can be subset by sample name
		make_libraries_csv(feature_type_params, fastq_paths, fastq_files_regex, samples, feature_types)

		// -------------------------------------------------------------------------------------------------
		// quantify datasets
		// -------------------------------------------------------------------------------------------------

		// make a channel containing all information for the quantification process
		parameters
			.combine(index_paths)
			.filter{it.first().get('genome') == it.last().get('key')}
			.map{it.first() + it.last().subMap('index path')}
			.map{it.subMap(['unique id', 'dataset id', 'description', 'limsid', 'index path'])}
			.dump(tag: 'quantification:cell_ranger_arc:datasets_to_quantify', pretty: true)
			.set{datasets_to_quantify}

		// make channels of parameters for samples that need to be quantified
		tags              = datasets_to_quantify.map{it.get('unique id')}
		ids               = datasets_to_quantify.map{it.get('dataset id')}
		descriptions      = datasets_to_quantify.map{it.get('description')}
		limsids           = datasets_to_quantify.map{it.get('limsid')}
		index_paths       = datasets_to_quantify.map{it.get('index path')}
		sample_sheet_file = make_libraries_csv.out.path

		// quantify the datasets
		count(datasets_to_quantify, tags, ids, descriptions, limsids, index_paths, sample_sheet_file)

		// make a channel of newly quantified datasets, each defined in a map
		merge_process_emissions(count, ['opt', 'libraries', 'quantification_path'])
			.map{rename_map_keys(it, ['libraries', 'quantification_path'], ['libraries_csv', 'quantification path'])}
			.map{merge_metadata_and_process_output(it)}
			.dump(tag: 'quantification:cell_ranger_arc:quantified_datasets', pretty: true)
			.set{quantified_datasets}

		// -------------------------------------------------------------------------------------------------
		// join any/all information back onto the parameters ready to emit
		// -------------------------------------------------------------------------------------------------

		parameters
			.combine(quantified_datasets)
			.filter{check_for_matching_key_values(it, ['unique id'])}
			.map{it.first() + it.last().subMap(['index path', 'libraries_csv', 'quantification path'])}
			.map{it + ['quantification method': 'cell_ranger_arc']}
			.dump(tag: 'quantification:cell_ranger_arc:final_results', pretty: true)
			.set{final_results}

		// -------------------------------------------------------------------------------------------------
		// make summary report for cell ranger arc stage
		// -------------------------------------------------------------------------------------------------

		// TODO: each task writes a version but all tasks have the same version information. use only first value of each process output channel

		// collate the software version yaml files into one channel
		concat_workflow_emissions([mkref, count], 'versions')
			.collect()
			.set{versions}

		// write a yaml with versions from all processes
		merge_software_versions(versions)

		// -------------------------------------------------------------------------------------------------
		// render a report for this part of the analysis
		// -------------------------------------------------------------------------------------------------

		// TODO: add process to render a chapter of a report

	emit:
		result = final_results
		report = channel.of('report.document')
}
