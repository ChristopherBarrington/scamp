
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { concat_workflow_emissions } from '../../utilities/concat_workflow_emissions'

include { cell_ranger }     from './cell_ranger'
include { cell_ranger_arc } from './cell_ranger_arc'

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
				def stages = it.get('stages')
				cell_ranger: stages.contains('quantification:cell_ranger')
				cell_ranger_arc: stages.contains('quantification:cell_ranger_arc')
				unknown: true}
			.set{quantification}

		quantification.cell_ranger.dump(tag: 'quantification:quantification.cell_ranger', pretty: true)
		quantification.cell_ranger_arc.dump(tag: 'quantification:quantification.cell_ranger_arc', pretty: true)
		quantification.unknown.dump(tag: 'quantification:quantification.unknown', pretty: true)

		// -------------------------------------------------------------------------------------------------
		// run the subworkflows
		// -------------------------------------------------------------------------------------------------

		cell_ranger(quantification.cell_ranger)
		cell_ranger_arc(quantification.cell_ranger_arc)

		// -------------------------------------------------------------------------------------------------
		// make channels of all outputs from the subworkflows
		// -------------------------------------------------------------------------------------------------

		// make a list of all subworkflows
		all_quantifications = [cell_ranger, cell_ranger_arc]

		// concatenate output channels from each subworkflow
		concat_workflow_emissions(all_quantifications, 'result')
			.concat(quantification.unknown)
			.set{all_results}

	emit:
		result = all_results
}
