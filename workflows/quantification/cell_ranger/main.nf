
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

// include { mkref } from '../../modules/cell_ranger/mkref'
include { count } from '../../../modules/cell_ranger/count'
include { mkref } from '../../../modules/cell_ranger/mkref'

include { check_for_matching_key_values }     from '../../../utilities/check_for_matching_key_values'
include { concat_workflow_emissions }         from '../../../utilities/concat_workflow_emissions'
include { merge_metadata_and_process_output } from '../../../utilities/merge_metadata_and_process_output'
include { merge_process_emissions }           from '../../../utilities/merge_process_emissions'
include { rename_map_keys }                   from '../../../utilities/rename_map_keys'

include { merge_yaml as merge_tasks } from '../../../modules/yq/merge_yaml'

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

		// branch parameters into two channels: {missing,provided} according to the presence of the 'index path' key
		parameters
			.map{it.get('genome parameters').subMap(['id', 'fasta file', 'gtf file']) + it.subMap('index path')}
			.unique()
			.branch{
				def index_provided = it.containsKey('index path')
				provided: index_provided == true
				missing: index_provided == false}
			.set{genome_indexes}

		genome_indexes.missing.dump(tag: 'quantification:cell_ranger:genome_indexes.missing', pretty: true)
		genome_indexes.provided.dump(tag: 'quantification:cell_ranger:genome_indexes.provided', pretty: true)

		// make channels of parameters for genomes that need indexes to be created
		tags        = genome_indexes.missing.map{it.get('id')}
		assemblies  = genome_indexes.missing.map{it.get('id')}
		fasta_files = genome_indexes.missing.map{it.get('fasta file')}
		gtf_files   = genome_indexes.missing.map{it.get('gtf file')}

		// create cell ranger arc indexes
		mkref(genome_indexes.missing, tags, assemblies, fasta_files, gtf_files)

		// make a channel of newly created genome indexes, each defined in a map
		merge_process_emissions(mkref, ['opt', 'path'])
			.map{rename_map_keys(it, 'path', 'index path')}
			.map{merge_metadata_and_process_output(it)}
			.concat(genome_indexes.provided)
			.dump(tag: 'quantification:cell_ranger:index_paths', pretty: true)
			.set{index_paths}

		// -------------------------------------------------------------------------------------------------
		// run cell ranger
		// -------------------------------------------------------------------------------------------------

		// make a channel containing all information for the quantification process
		parameters
			.combine(index_paths)
			.map{it.first() + it.last().subMap('index path')}
			.map{it.subMap(['dataset id', 'description', 'limsid', 'fastq paths', 'index path'])}
			.dump(tag: 'quantification:cell_ranger:datasets_to_quantify', pretty: true)
			.set{datasets_to_quantify}

		// make channels of parameters for samples that need to be quantified
		tags         = datasets_to_quantify.map{it.get('dataset id')}
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
			.dump(tag: 'quantification:cell_ranger:quantified_datasets', pretty: true)
			.set{quantified_datasets}

		// -------------------------------------------------------------------------------------------------
		// join any/all information back onto the parameters ready to emit
		// -------------------------------------------------------------------------------------------------

		parameters
			.combine(quantified_datasets)
			.filter{check_for_matching_key_values(it, ['dataset id'])}
			.map{it.first() + it.last().subMap(['index path', 'quantification path'])}
			.map{it + ['quantification method': 'cell_ranger']}
			.dump(tag: 'quantification:cell_ranger:final_results', pretty: true)
			.set{final_results}

		// -------------------------------------------------------------------------------------------------
		// make summary report for the workflow
		// -------------------------------------------------------------------------------------------------

		all_processes = [mkref, count]

		// collate the task yaml files into one
		concat_workflow_emissions(all_processes, 'task')
			.collect()
			.dump(tag: 'quantification:cell_ranger:tasks', pretty: true)
			.set{tasks}

		merge_tasks(tasks)

		// -------------------------------------------------------------------------------------------------
		// render a report for this part of the analysis
		// -------------------------------------------------------------------------------------------------

		// TODO: add process to render a chapter of a report

	emit:
		result = final_results
		tasks = tasks
}
