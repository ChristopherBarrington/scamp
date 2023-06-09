
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { check_for_matching_key_values } from '../../modules/utilities/check_for_matching_key_values'

include { cell_ranger as prepare_cell_ranger }         from '../../subworkflows/seurat/prepare/cell_ranger'
include { cell_ranger_arc as prepare_cell_ranger_arc } from '../../subworkflows/seurat/prepare/cell_ranger_arc'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow seurat {

	take:
		parameters

	main:
//		// -------------------------------------------------------------------------------------------------
//		// get the seurat parameters in order, collecting quantification paths as required
//		// -------------------------------------------------------------------------------------------------
//
//		// split the seurat analyses into those that are already quantified and those that were quantified here
//		channel
//			.fromList(parameters.findAll{x -> x.get('stage type').equals('seurat')})
//			.branch({
//				def quantification_path_provided = it.containsKey('quantification path')
//				internal: quantification_path_provided == false
//				external: quantification_path_provided == true})
//			.set{quantification_sources}
//
//		quantification_sources.internal.dump(tag:'seurat:quantification_sources.internal', pretty:true)
//		quantification_sources.external.dump(tag:'seurat:quantification_sources.external', pretty:true)
//
//		// get the quantification paths for the internal quantified datasets and join the remainder back on
//		quantification_sources.internal
//			.combine(quantification_results)
//			.filter{it.first().get('quantification stage') == it.last().get('stage name')}
//			.filter{check_for_matching_key_values(it, 'dataset name')}
//			.map{it.first() + it.last().subMap(['quantification path', 'index path']) + ['quantification type': it.last().get('stage type')]}
//			.concat(quantification_sources.external)
//			.dump(tag:'seurat:stage_parameters', pretty:true)
//			.set{stage_parameters}


		// -------------------------------------------------------------------------------------------------
		// split parameters if a seurat object is already prepared
		// -------------------------------------------------------------------------------------------------

		parameters
			.branch{
				def seurat_provided = it.containsKey('seurat file')
				provided: seurat_provided == true
				required: seurat_provided == false}
			.set{objects}

		objects.required.dump(tag: 'seurat:objects.required', pretty: true)
		objects.provided.dump(tag: 'seurat:objects.provided', pretty: true)

		// -------------------------------------------------------------------------------------------------
		// split unprepared datasets datasets into quantification method channels
		// -------------------------------------------------------------------------------------------------

		// branch the datasets based on how they were quantified; a different module for each method will be used
		objects.required
			.branch{
				def quantification_method = it.get('quantification method')
				allevin: quantification_method == 'alevin'
				cell_ranger: quantification_method == 'cell_ranger'
				cell_ranger_arc: quantification_method == 'cell_ranger_arc'
				kallisto_bustools: quantification_method == 'kallisto|bustools'
				other: true}
			.set{quantification_methods}

		quantification_methods.cell_ranger.dump(tag: 'seurat:quantification_methods.cell_ranger', pretty: true)
		quantification_methods.cell_ranger_arc.dump(tag: 'seurat:quantification_methods.cell_ranger_arc', pretty: true)
		quantification_methods.kallisto_bustools.dump(tag: 'seurat:quantification_methods.kallisto_bustools', pretty: true)
		quantification_methods.allevin.dump(tag: 'seurat:quantification_methods.allevin', pretty: true)

		// -------------------------------------------------------------------------------------------------
		// run the subworkflows
		// -------------------------------------------------------------------------------------------------

		prepare_cell_ranger(quantification_methods.cell_ranger)
		// cell_ranger_arc(quantification_methods.cell_ranger_arc)
}
