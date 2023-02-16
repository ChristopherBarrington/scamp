
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { count }              from '../../modules/cell_ranger_arc/count'
include { make_libraries_csv } from '../../modules/cell_ranger_arc/make_libraries_csv'
include { mkref }              from '../../modules/cell_ranger_arc/mkref'

include { check_for_matching_key_values }     from '../../modules/utilities/check_for_matching_key_values'
include { concat_workflow_emissions }         from '../../modules/utilities/concat_workflow_emissions'
include { get_feature_types }                 from '../../modules/utilities/get_feature_types'
include { make_map }                          from '../../modules/utilities/make_map'
include { merge_metadata_and_process_output } from '../../modules/utilities/merge_metadata_and_process_output'
include { merge_process_emissions }           from '../../modules/utilities/merge_process_emissions'
include { rename_map_keys }                   from '../../modules/utilities/rename_map_keys'

include { merge_yaml as merge_software_versions } from '../../modules/yq/merge_yaml'

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

		// branch parameters into two channels: {missing,provided} according to the presence of the 'index path' key
		channel
			.fromList(filtered_stage_parameters)
			.branch{
				def index_provided = it.containsKey('index path')
				missing: index_provided == false
				provided: index_provided == true}
			.set{stage_parameters_branched_by_index_path}

		stage_parameters_branched_by_index_path.missing.dump(tag:'quantification:cell_ranger_arc:stage_parameters_branched_by_index_path.missing', pretty:true)
		stage_parameters_branched_by_index_path.provided.dump(tag:'quantification:cell_ranger_arc:stage_parameters_branched_by_index_path.provided', pretty:true)

		stage_parameters_branched_by_index_path.missing
			.map{it.get('genome parameters')}
			.unique()
			.dump(tag:'quantification:cell_ranger_arc:genomes_with_missing_indexes', pretty:true)
			.set{genomes_with_missing_indexes}

		// make channels of parameters for genomes that need indexes to be created
		tags                = genomes_with_missing_indexes.map{it.get('genome')}
		organisms           = genomes_with_missing_indexes.map{it.get('organism')}
		assemblies          = genomes_with_missing_indexes.map{it.get('assembly')}
		non_nuclear_contigs = genomes_with_missing_indexes.map{it.get('non-nuclear contigs')}
		motifs              = genomes_with_missing_indexes.map{it.get('motifs')}
		path_to_fastas      = genomes_with_missing_indexes.map{it.get('fasta files')}
		path_to_gtfs        = genomes_with_missing_indexes.map{it.get('gtf files')}

		// create cell ranger arc indexes
		mkref(genomes_with_missing_indexes, tags, organisms, assemblies, non_nuclear_contigs, motifs, path_to_fastas, path_to_gtfs)

		// make a channel of newly created genome indexes, each defined in a map
		merge_process_emissions(mkref, ['metadata', 'path'])
			.map{rename_map_keys(it, 'path', 'index path')}
			.map{merge_metadata_and_process_output(it)}
			.combine(stage_parameters_branched_by_index_path.missing)
			.filter{check_for_matching_key_values(it, 'genome')}
			.map{it.last() + it.first().subMap('index path')}
			.concat(stage_parameters_branched_by_index_path.provided)
			.dump(tag: 'quantification:cell_ranger_arc:stage_parameters_with_index_paths', pretty: true)
			.set{stage_parameters_with_index_paths}

		// -------------------------------------------------------------------------------------------------
		// identify which datasets need to be quantified
		// -------------------------------------------------------------------------------------------------

		// branch datasets into two channels: {missing,provided} according to the presence of the 'quantification path' key
		stage_parameters_with_index_paths
			.branch({
				def quantification_provided = it.containsKey('quantification path')
				missing: quantification_provided == false
				provided: quantification_provided == true})
			.set{dataset_quantification}

		dataset_quantification.missing.dump(tag: 'quantification:cell_ranger_arc:dataset_quantification.missing', pretty: true)
		dataset_quantification.provided.dump(tag: 'quantification:cell_ranger_arc:dataset_quantification.provided', pretty: true)

		// -------------------------------------------------------------------------------------------------
		// make a sample sheet of all samples in any dataset that should be quantified
		// -------------------------------------------------------------------------------------------------

		// when there is at least one missing quantification, prepare a channel to create the sample sheet
		dataset_quantification.missing
			.first()
			.map{get_feature_types()}
			.map{it + [fastq_paths:filtered_stage_parameters.collect{it.get('fastq paths')}.flatten().unique()]}
			.map{it + [fastq_files_regex:'(.*)_S[0-9]+_L[0-9]+_R1_001.fastq.gz']}
			.dump(tag:'feature_type_params', pretty:true)
			.set{feature_type_params}

		// make channels to create the libraries csv file that cell ranger arc count expects
		fastq_paths       = feature_type_params.map{it.get('fastq_paths')}
		fastq_files_regex = feature_type_params.map{it.get('fastq_files_regex')}
		samples           = feature_type_params.map{it.get('sample_names')}
		feature_types     = feature_type_params.map{it.get('feature_types')}

		make_libraries_csv(feature_type_params, fastq_paths, fastq_files_regex, samples, feature_types)

		// make a channel of newly created genome indexes, each defined in a map
		merge_process_emissions(make_libraries_csv, ['metadata', 'path'])
			.map{rename_map_keys(it, 'path', 'project_libraries_csv')}
			.map{merge_metadata_and_process_output(it)}
			.dump(tag: 'quantification:cell_ranger_arc:project_libraries_csv', pretty: true)
			.set{project_libraries_csv}

		// -------------------------------------------------------------------------------------------------
		// quantify datasets that do not provide a `quantification path`
		// -------------------------------------------------------------------------------------------------

		dataset_quantification.missing
			.combine(project_libraries_csv)
			.map{it.first() + it.last().subMap('project_libraries_csv')}
			.dump(tag: 'quantification:cell_ranger_arc:datasets_to_quantify', pretty: true)
			.set{datasets_to_quantify}

		// make channels of parameters for samples that need to be quantified
		tags                 = datasets_to_quantify.map{it.get('dataset name')}
		dataset_directories  = datasets_to_quantify.map{it.get('dataset dir')}
		samples              = datasets_to_quantify.map{it.get('samples')}
		additional_arguments = datasets_to_quantify.map{it.get('additional arguments', '')}
		index_paths          = datasets_to_quantify.map{it.get('index path')}
		sample_sheet_file    = datasets_to_quantify.map{it.get('project_libraries_csv')}

		count(datasets_to_quantify, tags, dataset_directories, samples, additional_arguments, index_paths, sample_sheet_file)

		// make a channel of newly quantified datasets, each defined in a map
		merge_process_emissions(count, ['metadata', 'libraries', 'quantification_path'])
			.map{rename_map_keys(it, ['libraries', 'quantification_path'], ['libraries_csv', 'quantification path'])}
			.map{merge_metadata_and_process_output(it)}
			.concat(dataset_quantification.provided)
			.dump(tag:'quantification:cell_ranger_arc:stage_parameters_with_quantification_paths', pretty:true)
			.set{stage_parameters_with_quantification_paths}

		// -------------------------------------------------------------------------------------------------
		// make summary report for cell ranger arc stage
		// -------------------------------------------------------------------------------------------------

		// collate the software version yaml files into one
		concat_workflow_emissions([mkref, count], 'versions')
			.collect()
			.set{versions}

		merge_software_versions(versions)

		// -------------------------------------------------------------------------------------------------
		// render a report for this part of the analysis
		// -------------------------------------------------------------------------------------------------

		// TODO: add process to render a chapter of a report

	emit:
		result = stage_parameters_with_quantification_paths
		report = channel.of('report.document')
}
