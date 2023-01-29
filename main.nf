


// get workflows for this pipeline

include { quantification } from './workflows/quantification'
include { seurat } from './workflows/seurat'

include { get_complete_stage_parameters ; make_map ; print_as_json } from './modules/utilities'

// define the workflow for this pipeline

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
		quantification.out.subworkflows
			.merge(quantification.out.unique_ids)
			.merge(quantification.out.stage_names)
			.merge(quantification.out.dataset_names)
			.merge(quantification.out.index_paths)
			.merge(quantification.out.quantification_paths)
			.map{make_map(it, ['quantification method', 'unique id', 'stage name', 'dataset name', 'index path', 'quantification path'])}
			.dump(tag: 'quantification', pretty: true)
			.set{quantification}

		// -------------------------------------------------------------------------------------------------
		// run seurat workflow
		// -------------------------------------------------------------------------------------------------

		seurat(complete_stage_parameters, quantification)		
}
