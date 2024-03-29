
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { cat as combine_workflow_records } from '../../modules/tools/cat'

include { concat_workflow_emissions } from '../../utilities/concat_workflow_emissions'

include { cell_ranger }     from './cell_ranger'
include { cell_ranger_arc } from './cell_ranger_arc'
include { cell_ranger_multi } from './cell_ranger_multi'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow quantification {

	take:
		parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// branch the parameters by quantification method
		// -------------------------------------------------------------------------------------------------

		// branch parameters into multiple channels according to the 'quantification method' key
		parameters
			.branch{
				def workflows = it.get('workflows')
				cell_ranger: workflows.contains('quantification:cell_ranger')
				cell_ranger_arc: workflows.contains('quantification:cell_ranger_arc')
				cell_ranger_multi: workflows.contains('quantification:cell_ranger_multi')
				unknown: true}
			.set{quantification}

		quantification.cell_ranger.dump(tag: 'quantification:quantification.cell_ranger', pretty: true)
		quantification.cell_ranger_arc.dump(tag: 'quantification:quantification.cell_ranger_arc', pretty: true)
		quantification.cell_ranger_multi.dump(tag: 'quantification:quantification.cell_ranger_multi', pretty: true)
		quantification.unknown.dump(tag: 'quantification:quantification.unknown', pretty: true)

		// -------------------------------------------------------------------------------------------------
		// run the workflows
		// -------------------------------------------------------------------------------------------------

		cell_ranger(quantification.cell_ranger)
		cell_ranger_arc(quantification.cell_ranger_arc)
		cell_ranger_multi(quantification.cell_ranger_multi)

		// -------------------------------------------------------------------------------------------------
		// make channels of all outputs from the workflows
		// -------------------------------------------------------------------------------------------------

		// make a list of all workflows
		all_quantifications = [cell_ranger, cell_ranger_arc, cell_ranger_multi]

		// concatenate output channels from each workflow
		concat_workflow_emissions(all_quantifications, 'result')
			.concat(quantification.unknown)
			.dump(tag: 'quantification:result', pretty: true)
			.set{result}

		concat_workflow_emissions(all_quantifications, 'tasks')
			.collect()
			.dump(tag: 'quantification:tasks', pretty: true)
			.set{tasks}

		combine_workflow_records([:], tasks, '*.yaml', 'tasks.yaml', 'true')

	emit:
		result = result
		tasks = tasks
}
