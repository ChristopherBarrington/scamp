
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { check_for_matching_key_values } from '../../modules/utilities/check_for_matching_key_values'

include { cell_ranger } from '../../subworkflows/seurat/prepare/cell_ranger'
include { cell_ranger_arc } from '../../subworkflows/seurat/prepare/cell_ranger_arc'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow seurat {
	take:
		complete_stage_parameters
		quantification_results

	main:
		// -------------------------------------------------------------------------------------------------
		// get the seurat parameters in order, collecting quantification paths as required
		// -------------------------------------------------------------------------------------------------

		// split the seurat analyses into those that are already quantified and those that were quantified here
		channel
			.fromList(complete_stage_parameters.findAll{x -> x.get('stage type').equals('seurat')})
			.branch({
				def quantification_path_provided = it.containsKey('quantification path')
				internal: quantification_path_provided == false
				external: quantification_path_provided == true})
			.set{quantification_sources}

		quantification_sources.internal.dump(tag:'seurat:quantification_sources.internal', pretty:true)
		quantification_sources.external.dump(tag:'seurat:quantification_sources.external', pretty:true)

		// get the quantification paths for the internal quantified datasets and join the remainder back on
		quantification_sources.internal
			.combine(quantification_results)
			.filter{it.first().get('quantification stage') == it.last().get('stage name')}
			.filter{check_for_matching_key_values(it, 'dataset name')}
			.map{it.first() + it.last().subMap(['quantification path', 'index path']) + ['quantification type': it.last().get('stage type')]}
			.concat(quantification_sources.external)
			.dump(tag:'seurat:stage_parameters', pretty:true)
			.set{stage_parameters}

		// -------------------------------------------------------------------------------------------------
		// split quantified datasets into quantification method channels
		// -------------------------------------------------------------------------------------------------

		// branch the datasets based on how they were quantified; a different module for each method will be used
		stage_parameters
			.branch({
				quantification_method = it.get('quantification type')
				cell_ranger: quantification_method == 'cell ranger'
				cell_ranger_arc: quantification_method == 'cell ranger arc'
				kallisto_bustools: quantification_method == 'kallisto|bustools'
				allevin: quantification_method == 'alevin'})
			.set{quantification_methods}

		quantification_methods.cell_ranger.dump(tag:'seurat:quantification_methods.cell_ranger', pretty:true)
		quantification_methods.cell_ranger_arc.dump(tag:'seurat:quantification_methods.cell_ranger_arc', pretty:true)
		quantification_methods.kallisto_bustools.dump(tag:'seurat:quantification_methods.kallisto_bustools', pretty:true)
		quantification_methods.allevin.dump(tag:'seurat:quantification_methods.allevin', pretty:true)

		// -------------------------------------------------------------------------------------------------
		// run the subworkflows
		// -------------------------------------------------------------------------------------------------

		cell_ranger(quantification_methods.cell_ranger)
		cell_ranger_arc(quantification_methods.cell_ranger_arc)
}
