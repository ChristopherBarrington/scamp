
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

// include { mkref } from '../../modules/cell_ranger/mkref'
include { count as quantify } from '../../modules/cell_ranger/count'

include { check_for_matching_key_values }     from '../../modules/utilities/check_for_matching_key_values'
include { concat_workflow_emissions }         from '../../modules/utilities/concat_workflow_emissions'
include { merge_metadata_and_process_output } from '../../modules/utilities/merge_metadata_and_process_output'
include { merge_process_emissions }           from '../../modules/utilities/merge_process_emissions'
include { rename_map_keys }                   from '../../modules/utilities/rename_map_keys'

include { merge_yaml as merge_software_versions } from '../../modules/yq/merge_yaml'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow cell_ranger {

	take:
		filtered_stage_parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// create missing cell ranger indexes
		// -------------------------------------------------------------------------------------------------

		// currently assume they are pre-built and ready

		// -------------------------------------------------------------------------------------------------
		// run cell ranger
		// -------------------------------------------------------------------------------------------------

		// make a channel containing all information for the quantification process
		channel
			.fromList(filtered_stage_parameters)
			// .combine(index_paths)
			// .filter{check_for_matching_key_values(it, 'genome')}
			// .map{it.first() + it.last().subMap('index path')}
			.map{it.subMap(['unique id', 'sample', 'fastq paths', 'index path', 'dataset id'])}
			.dump(tag: 'quantification:cell_ranger:datasets_to_quantify', pretty: true)
			.set{datasets_to_quantify}

		// make channels of parameters for samples that need to be quantified
		tags              = datasets_to_quantify.map{it.get('unique id')}
		sample            = datasets_to_quantify.map{it.get('sample')}
		fastq_paths       = datasets_to_quantify.map{it.get('fastq paths')}
		index_paths       = datasets_to_quantify.map{it.get('index path')}

		// quantify the datasets
		quantify(datasets_to_quantify, tags, sample, fastq_paths, index_paths)

		// make a channel of dataset (names) and paths that contain quantified data
		merge_process_emissions(quantify, ['opt', 'quantification_path'])
			.map{rename_map_keys(it, ['quantification_path'], ['quantification path'])}
			.map{merge_metadata_and_process_output(it)}
			.dump(tag:'quantification:cell_ranger:quantified_datasets', pretty:true)
			.set{quantified_datasets}

		// -------------------------------------------------------------------------------------------------
		// join any/all information back onto the parameters ready to emit
		// -------------------------------------------------------------------------------------------------

		channel
			.fromList(filtered_stage_parameters)
			.combine(quantified_datasets)
			.dump(tag:'working', pretty:true)
			.filter{check_for_matching_key_values(it, ['unique id'])}
			.map{it.first() + it.last().subMap(['index path', 'quantification path'])}
			.dump(tag:'quantification:cell_ranger:final_results', pretty:true)
			.set{final_results}

		// -------------------------------------------------------------------------------------------------
		// make summary report for cell ranger arc stage
		// -------------------------------------------------------------------------------------------------

		// TODO: each task writes a version but all tasks have the same version information. use only first value of each process output channel

		// collate the software version yaml files into one channel
		concat_workflow_emissions([quantify], 'versions')
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
