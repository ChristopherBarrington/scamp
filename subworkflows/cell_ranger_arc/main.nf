
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { count as quantify }   from '../../modules/cell_ranger_arc/count'
include { make_libraries_csv }  from '../../modules/cell_ranger_arc/make_libraries_csv'
include { mkref as make_index } from '../../modules/cell_ranger_arc/mkref'

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
			.map{it.get('genome parameters').subMap(['genome', 'organism', 'assembly', 'non-nuclear contigs', 'motifs', 'fasta files', 'gtf files']) + it.subMap('index path')}
			.unique()
			.branch{
				def index_provided = it.containsKey('index path')
				provided: index_provided == true
				missing: index_provided == false}
			.set{genome_indexes}

		genome_indexes.missing.dump(tag:'quantification:cell_ranger_arc:genome_indexes.missing', pretty:true)
		genome_indexes.provided.dump(tag:'quantification:cell_ranger_arc:genome_indexes.provided', pretty:true)

		// make channels of parameters for genomes that need indexes to be created
		tags                = genome_indexes.missing.map{it.get('genome')}
		organisms           = genome_indexes.missing.map{it.get('organism')}
		assemblies          = genome_indexes.missing.map{it.get('assembly')}
		non_nuclear_contigs = genome_indexes.missing.map{it.get('non-nuclear contigs')}
		motifs              = genome_indexes.missing.map{it.get('motifs')}
		path_to_fastas      = genome_indexes.missing.map{it.get('fasta files')}
		path_to_gtfs        = genome_indexes.missing.map{it.get('gtf files')}

		// create cell ranger arc indexes
		make_index(genome_indexes.missing, tags, organisms, assemblies, non_nuclear_contigs, motifs, path_to_fastas, path_to_gtfs)

		// make a channel of newly created genome indexes, each defined in a map
		merge_process_emissions(make_index, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'index path')}
			.map{merge_metadata_and_process_output(it)}
			.concat(genome_indexes.provided)
			.dump(tag: 'quantification:cell_ranger_arc:index_paths', pretty: true)
			.set{index_paths}

		// -------------------------------------------------------------------------------------------------
		// make a sample sheet of all samples in any dataset that should be quantified
		// -------------------------------------------------------------------------------------------------

		// when there is at least one dataset to quantify, prepare a channel to create the sample sheet
		channel
			.fromList(filtered_stage_parameters)
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

		// make a sample sheet for the whole project which can be subset by sample name
		make_libraries_csv(feature_type_params, fastq_paths, fastq_files_regex, samples, feature_types)

		// -------------------------------------------------------------------------------------------------
		// quantify datasets
		// -------------------------------------------------------------------------------------------------

		// make a channel containing all information for the quantification process
		channel
			.fromList(filtered_stage_parameters)
			.combine(index_paths)
			.filter{check_for_matching_key_values(it, 'genome')}
			.map{it.first() + it.last().subMap('index path')}
			.map{it.subMap(['unique id', 'samples', 'index path', 'dataset id'])}
			.dump(tag: 'quantification:cell_ranger_arc:datasets_to_quantify', pretty: true)
			.set{datasets_to_quantify}

		// make channels of parameters for samples that need to be quantified
		tags              = datasets_to_quantify.map{it.get('unique id')}
		samples           = datasets_to_quantify.map{it.get('samples')}
		index_paths       = datasets_to_quantify.map{it.get('index path')}
		sample_sheet_file = make_libraries_csv.out.path

		// quantify the datasets
		quantify(datasets_to_quantify, tags, samples, index_paths, sample_sheet_file)

		// make a channel of newly quantified datasets, each defined in a map
		merge_process_emissions(quantify, ['opt', 'libraries', 'quantification_path'])
			.map{rename_map_keys(it, ['libraries', 'quantification_path'], ['libraries_csv', 'quantification path'])}
			.map{merge_metadata_and_process_output(it)}
			.dump(tag:'quantification:cell_ranger_arc:quantified_datasets', pretty:true)
			.set{quantified_datasets}

		// -------------------------------------------------------------------------------------------------
		// join any/all information back onto the parameters ready to emit
		// -------------------------------------------------------------------------------------------------

		channel
			.fromList(filtered_stage_parameters)
			.combine(quantified_datasets)
			.filter{check_for_matching_key_values(it, ['unique id'])}
			.map{it.first() + it.last().subMap(['index path', 'libraries_csv', 'quantification path'])}
			.dump(tag:'quantification:cell_ranger_arc:final_results', pretty:true)
			.set{final_results}

		// -------------------------------------------------------------------------------------------------
		// make summary report for cell ranger arc stage
		// -------------------------------------------------------------------------------------------------

		// TODO: each task writes a version but all tasks have the same version information. use only first value of each process output channel

		// collate the software version yaml files into one channel
		concat_workflow_emissions([make_index, quantify], 'versions')
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
