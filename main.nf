
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { quantification } from './workflows/quantification'
include { seurat }         from './workflows/seurat'

include { print_as_json } from './modules/utilities/print_as_json'

include { get_complete_analysis_parameters } from './modules/utilities/get_complete_analysis_parameters'
include { make_map }                         from './modules/utilities/make_map'
include { print_pipeline_title }             from './modules/utilities/print_pipeline_title'

print_pipeline_title()

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow {

	main:
		// -------------------------------------------------------------------------------------------------
		// collect a list of parameter maps for every analysis in the parameters file
		// -------------------------------------------------------------------------------------------------

		complete_analysis_parameters = get_complete_analysis_parameters()
		channel
			.fromList(complete_analysis_parameters)
			.dump(tag: 'complete_analysis_parameters', pretty: true)

		// -------------------------------------------------------------------------------------------------
		// run quantification workflows
		// -------------------------------------------------------------------------------------------------

		// branch parameters into two channels: {provided,required} according to presence of the 'quantification path' key
		channel
			.fromList(complete_analysis_parameters)
			.branch{
				def has_a_quantification_stage = it.get('stages').collect{it.startsWith('quantification:')}.any()
				def quantification_provided = it.containsKey('quantification path')
				provided: quantification_provided == true
				required: has_a_quantification_stage == true && quantification_provided == false}
			.set{dataset_quantification}

		dataset_quantification.required.dump(tag: 'scamp:dataset_quantification.required', pretty: true)
		dataset_quantification.provided.dump(tag: 'scamp:dataset_quantification.provided', pretty: true)

		// quantify datasets that do not have a `quantification path` using some method
		// these should return with `quantification path` and `quantification method` now included
		quantification(dataset_quantification.required)

		// concatenate the result of quantification and the datasets that are pre-quantified
		quantification.out.result
			.concat(dataset_quantification.provided)
			.dump(tag: 'scamp:post_quantification_results', pretty: true)
			.set{post_quantification_results}

		// -------------------------------------------------------------------------------------------------
		// run analysis workflows
		// -------------------------------------------------------------------------------------------------

		// branch parameters into channels according to the analysis workflow
		post_quantification_results
			.branch{
				def has_a_seurat_stage = it.get('stages').collect{it.startsWith('seurat:')}.any()
				seurat: has_a_seurat_stage == true
				other: true
			}
			.set{analysis_workflows}

		analysis_workflows.seurat.dump(tag: 'scamp:analysis_workflows.seurat', pretty: true)
		analysis_workflows.other.dump(tag: 'scamp:analysis_workflows.other', pretty: true)

		// process datasets that contain a `seurat` analysis stage
		// seurat(analysis_workflows.seurat)

		// concatenate the result of the seurat subworkflow and the non-seurat datasets
//		seurat.out.result
//			.concat(seurat_subworkflow_datasets.no)
//			.dump(tag: 'scamp:post_seurat_results', pretty: true)
//			.set{post_seurat_results}
}
