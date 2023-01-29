
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { cell_ranger } from '../../subworkflows/cell_ranger'
include { cell_ranger_arc } from '../../subworkflows/cell_ranger_arc'

include { concat_workflow_emissions ; print_as_json } from '../../modules/utilities'

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
		all_subworkflows         = concat_workflow_emissions(all_quantifications, 'subworkflows')
		all_unique_ids           = concat_workflow_emissions(all_quantifications, 'unique_ids')
		all_stage_names          = concat_workflow_emissions(all_quantifications, 'stage_names')
		all_dataset_names        = concat_workflow_emissions(all_quantifications, 'dataset_names')
		all_index_paths          = concat_workflow_emissions(all_quantifications, 'index_paths')
		all_quantification_paths = concat_workflow_emissions(all_quantifications, 'quantification_paths')

	emit:
		subworkflows         = all_subworkflows
		unique_ids           = all_unique_ids
		stage_names          = all_stage_names
		dataset_names        = all_dataset_names
		index_paths          = all_index_paths
		quantification_paths = all_quantification_paths
}
