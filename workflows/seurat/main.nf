
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { cat as combine_workflow_records } from '../../modules/tools/cat'

include { check_for_matching_key_values } from '../../utilities/check_for_matching_key_values'
include { concat_workflow_emissions }     from '../../utilities/concat_workflow_emissions'

include { cell_ranger as prepare_cell_ranger }         from './prepare/cell_ranger'
include { cell_ranger_arc as prepare_cell_ranger_arc } from './prepare/cell_ranger_arc'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow seurat {

	take:
		parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// split parameters if a seurat object is already prepared
		// -------------------------------------------------------------------------------------------------

		parameters
			.branch{
				def seurat_provided = it.containsKey('seurat file')
				provided: seurat_provided
				required: !seurat_provided}
			.set{objects}

		objects.required.dump(tag: 'seurat:objects.required', pretty: true)
		objects.provided.dump(tag: 'seurat:objects.provided', pretty: true)

		// -------------------------------------------------------------------------------------------------
		// prepare objects based on quantification methods
		// -------------------------------------------------------------------------------------------------

		// branch the datasets based on how they were quantified; a different module for each method will be used
		objects.required
			.branch{
				def quantification_method = it.get('quantification method')
				allevin: quantification_method == 'alevin'
				cell_ranger: quantification_method == 'cell_ranger'
				cell_ranger_arc: quantification_method == 'cell_ranger_arc'
				kallisto_bustools: quantification_method == 'kallisto|bustools'
				unknown: true}
			.set{quantified_by}

		quantified_by.allevin.dump(tag: 'seurat:quantified_by.allevin', pretty: true)
		quantified_by.cell_ranger.dump(tag: 'seurat:quantified_by.cell_ranger', pretty: true)
		quantified_by.cell_ranger_arc.dump(tag: 'seurat:quantified_by.cell_ranger_arc', pretty: true)
		quantified_by.kallisto_bustools.dump(tag: 'seurat:quantified_by.kallisto_bustools', pretty: true)
		quantified_by.unknown.dump(tag: 'seurat:quantified_by.unknown', pretty: true)

		// run the analysis workflows
		prepare_cell_ranger(quantified_by.cell_ranger)
		prepare_cell_ranger_arc(quantified_by.cell_ranger_arc)

		// -------------------------------------------------------------------------------------------------
		// concatenate the results of all workflows
		// -------------------------------------------------------------------------------------------------

		all_workflows = [prepare_cell_ranger, prepare_cell_ranger_arc]
		concat_workflow_emissions(all_workflows, 'result')
			.concat(quantified_by.unknown)
			.dump(tag: 'seurat:result', pretty: true)
			.set{result}

		concat_workflow_emissions(all_workflows, 'tasks')
			.collect()
			.dump(tag: 'seurat:tasks', pretty: true)
			.set{tasks}

		combine_task_records([:], tasks, '*.yaml', 'tasks.yaml', 'true')

	emit:
		result = result
		tasks = tasks
}
