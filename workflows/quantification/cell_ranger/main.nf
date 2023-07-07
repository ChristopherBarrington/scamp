
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

// include { mkref } from '../../modules/cell_ranger/mkref'
include { count } from '../../../modules/cell_ranger/count'

include { check_for_matching_key_values }     from '../../../utilities/check_for_matching_key_values'
include { concat_workflow_emissions }         from '../../../utilities/concat_workflow_emissions'
include { merge_metadata_and_process_output } from '../../../utilities/merge_metadata_and_process_output'
include { merge_process_emissions }           from '../../../utilities/merge_process_emissions'
include { rename_map_keys }                   from '../../../utilities/rename_map_keys'

include { merge_yaml as merge_software_versions } from '../../../modules/yq/merge_yaml'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow cell_ranger {

	take:
		parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// create missing cell ranger indexes
		// -------------------------------------------------------------------------------------------------

		// currently assume they are pre-built and ready

		// -------------------------------------------------------------------------------------------------
		// run cell ranger
		// -------------------------------------------------------------------------------------------------

		// make a channel containing all information for the quantification process
		parameters
			.map{it.subMap(['unique id', 'dataset id', 'description', 'limsid', 'fastq paths', 'index path'])}
			.dump(tag:'quantification:cell_ranger:datasets_to_quantify', pretty:true)
			.set{datasets_to_quantify}

		// make channels of parameters for samples that need to be quantified
		tags         = datasets_to_quantify.map{it.get('unique id')}
		ids          = datasets_to_quantify.map{it.get('dataset id')}
		descriptions = datasets_to_quantify.map{it.get('description')}
		limsids      = datasets_to_quantify.map{it.get('limsid')}
		fastq_paths  = datasets_to_quantify.map{it.get('fastq paths')}
		index_paths  = datasets_to_quantify.map{it.get('index path')}

		// quantify the datasets
		count(datasets_to_quantify, tags, ids, descriptions, limsids, fastq_paths, index_paths)

		// make a channel of dataset (names) and paths that contain quantified data
		merge_process_emissions(count, ['opt', 'quantification_path'])
			.map{rename_map_keys(it, ['quantification_path'], ['quantification path'])}
			.map{merge_metadata_and_process_output(it)}
			.dump(tag:'quantification:cell_ranger:quantified_datasets', pretty:true)
			.set{quantified_datasets}

		// -------------------------------------------------------------------------------------------------
		// join any/all information back onto the parameters ready to emit
		// -------------------------------------------------------------------------------------------------

		parameters
			.combine(quantified_datasets)
			.filter{check_for_matching_key_values(it, ['unique id'])}
			.map{it.first() + it.last().subMap(['index path', 'quantification path'])}
			.map{it + ['quantification method': 'cell_ranger']}
			.dump(tag:'quantification:cell_ranger:final_results', pretty:true)
			.set{final_results}

		// -------------------------------------------------------------------------------------------------
		// make summary report for cell ranger arc stage
		// -------------------------------------------------------------------------------------------------

		// TODO: each task writes a version but all tasks have the same version information. use only first value of each process output channel

		// collate the software version yaml files into one channel
		concat_workflow_emissions([count], 'versions')
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
