
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { quantification } from './workflows/quantification'
include { seurat }         from './workflows/seurat'

include { print_as_json } from './modules/utilities/print_as_json'

include { get_complete_stage_parameters } from './modules/utilities/get_complete_stage_parameters'
include { make_map }                      from './modules/utilities/make_map'
include { print_pipeline_title }          from './modules/utilities/print_pipeline_title'

print_pipeline_title()

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow {
	
	main:
		// -------------------------------------------------------------------------------------------------
		// collect a list of parameter maps for every analysis in the parameters file
		// -------------------------------------------------------------------------------------------------

		complete_stage_parameters = get_complete_stage_parameters()
		channel
			.fromList(complete_stage_parameters)
			.dump(tag: 'complete_stage_parameters', pretty: true)

		// -------------------------------------------------------------------------------------------------
		// run quantification workflows
		// -------------------------------------------------------------------------------------------------

		quantification(complete_stage_parameters)
		quantification.out.result
			.dump(tag: 'quantification_results', pretty: true)
			.set{quantification_results}

		// -------------------------------------------------------------------------------------------------
		// run seurat workflow
		// -------------------------------------------------------------------------------------------------

		seurat(complete_stage_parameters, quantification_results)		
}
