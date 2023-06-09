
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { concat_workflow_emissions } from '../../modules/utilities/concat_workflow_emissions'

include { cell_ranger }     from '../../subworkflows/cell_ranger'
include { cell_ranger_arc } from '../../subworkflows/cell_ranger_arc'

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
				kallisto: stages.contains('quantification:kallisto')}
			.set{quantification}

		quantification.cell_ranger.dump(tag: 'quantification:quantification.cell_ranger', pretty: true)
		quantification.cell_ranger_arc.dump(tag: 'quantification:quantification.cell_ranger_arc', pretty: true)
		quantification.kallisto.dump(tag: 'quantification:quantification.kallisto', pretty: true)

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
		all_results = concat_workflow_emissions(all_quantifications, 'result')

	emit:
		result = all_results
}
