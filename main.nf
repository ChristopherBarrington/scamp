
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { genome_preparation } from './workflows/genome_preparation'
include { quantification }     from './workflows/quantification'
include { seurat }             from './workflows/seurat'

include { concat_workflow_emissions } from './utilities/concat_workflow_emissions'
include { make_map }                  from './utilities/make_map'
include { print_pipeline_title }      from './utilities/print_pipeline_title'
include { validate_scamp_parameters } from './utilities/validate_scamp_parameters'

include { cat as combine_workflow_records } from './modules/tools/cat'

include { print_as_json } from './utilities/print_as_json'

print_pipeline_title()

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow {

	main:
		// -------------------------------------------------------------------------------------------------
		// collect a list of parameter maps for every analysis in the parameters file
		// -------------------------------------------------------------------------------------------------

		channel
			.fromList(validate_scamp_parameters())
			.dump(tag: 'scamp:validated_scamp_parameters', pretty: true)
			.set{validated_scamp_parameters}

		// -------------------------------------------------------------------------------------------------
		// run genome workflow, independent of dataset parameters
		// -------------------------------------------------------------------------------------------------

		genome_preparation(validated_scamp_parameters).result
			.dump(tag: 'scamp:complete_analysis_parameters', pretty: true)
			.set{complete_analysis_parameters}

		// -------------------------------------------------------------------------------------------------
		// run quantification workflows
		// -------------------------------------------------------------------------------------------------

		// branch parameters into two channels: {provided,required} according to presence of the 'quantification path' key
		complete_analysis_parameters
			.branch{
				def has_a_quantification_workflow = it.get('workflows').collect{it.startsWith('quantification:')}.any()
				def quantification_provided = it.containsKey('quantification path')
				provided: quantification_provided
				required: has_a_quantification_workflow & !quantification_provided}
			.set{dataset_quantification}

		dataset_quantification.required.dump(tag: 'scamp:dataset_quantification.required', pretty: true)
		dataset_quantification.provided.dump(tag: 'scamp:dataset_quantification.provided', pretty: true)

		// quantify datasets that do not have a `quantification path` using some method
		// these should return with `quantification path` and `quantification method` now included
		quantification(dataset_quantification.required)

		// concatenate the result of quantification and the datasets that are pre-quantified
		quantification.out.result
			.concat(dataset_quantification.provided)
			.dump(tag: 'scamp:quantification_results', pretty: true)
			.set{quantification_results}

		// -------------------------------------------------------------------------------------------------
		// run analysis workflows
		// -------------------------------------------------------------------------------------------------

		// branch parameters into channels according to the analysis workflow
		quantification_results
			.branch{
				def has_a_seurat_workflow = it.get('workflows').collect{it.startsWith('seurat:')}.any()
				seurat: has_a_seurat_workflow
				unknown: true
			}
			.set{analysis_workflows}

		analysis_workflows.seurat.dump(tag: 'scamp:analysis_workflows.seurat', pretty: true)
		analysis_workflows.unknown.dump(tag: 'scamp:analysis_workflows.unknown', pretty: true)

		// process datasets with the indicated analysis workflow
		seurat(analysis_workflows.seurat)

		// concatenate the results of analysis workflows
		all_workflows = [seurat]
		concat_workflow_emissions(all_workflows, 'result')
			.concat(analysis_workflows.unknown)
			.dump(tag: 'scamp:analysis_results', pretty: true)
			.set{analysis_results}

		// -------------------------------------------------------------------------------------------------
		// concatenate the results of all workflows
		// -------------------------------------------------------------------------------------------------

		all_workflows = [quantification, seurat]
		concat_workflow_emissions(all_workflows, 'tasks')
			.collect()
			.dump(tag: 'scamp:tasks', pretty: true)
			.set{tasks}

		combine_workflow_records([:], tasks, '*.yaml', 'tasks.yaml', 'true')
}
