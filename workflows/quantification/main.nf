
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
		complete_stage_parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// define parameter sets for each subworkflow
		// -------------------------------------------------------------------------------------------------

		cell_ranger_params = complete_stage_parameters.findAll{x -> x.get('stage type').equals('cell ranger')}
		cell_ranger_arc_params = complete_stage_parameters.findAll{x -> x.get('stage type').equals('cell ranger arc')}

		// -------------------------------------------------------------------------------------------------
		// run the subworkflows
		// -------------------------------------------------------------------------------------------------

		cell_ranger(cell_ranger_params)
		cell_ranger_arc(cell_ranger_arc_params)

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
