
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { read_matrix as read_cell_ranger_arc_output } from '../../modules/seurat/read_matrices/cell_ranger/arc'

include { check_for_matching_key_values ; format_unique_key ; print_as_json ; val_to_path } from '../../modules/utilities'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow seurat {
	take:
		complete_stage_parameters
		quantified_datasets

	main:
		// -------------------------------------------------------------------------------------------------
		// get the seurat parameters in order, collecting quantification paths as required
		// -------------------------------------------------------------------------------------------------

		seurat_parameters = complete_stage_parameters.findAll{x -> x.get('stage type').equals('seurat')}

		// split the seurat analyses into those that are already quantified and those that were quantified here
		channel
			.fromList(seurat_parameters)
			.branch({
				def quantification_path_provided = it.containsKey('quantification path')
				internal: quantification_path_provided == false
				external: quantification_path_provided == true})
			.set{quantification_sources}

		quantification_sources.internal.dump(tag:'seurat:quantification_sources.internal', pretty:true)
		quantification_sources.external.dump(tag:'seurat:quantification_sources.external', pretty:true)

		// get the quantification paths for the internal quantified datasets and join the remainder back on
		quantification_sources.internal
			.combine(quantified_datasets)
			.filter{format_unique_key(it.first().subMap(['quantification stage','dataset name'])) == it.last().get('unique id')}
			.map{it.first() + it.last().subMap(['quantification method', 'quantification path', 'index path'])}
			.concat(quantification_sources.external)
			.dump(tag:'filtered_stage_parameters', pretty:true)
			.set{filtered_stage_parameters}

		// -------------------------------------------------------------------------------------------------
		// read expression matrices into r
		// -------------------------------------------------------------------------------------------------

		// branch the datasets based on how they were quantified; a different module for each method will be used
		filtered_stage_parameters
			.branch({
				quantification_method = it.get('quantification method')
				cell_ranger: quantification_method == 'cell ranger'
				cell_ranger_arc: quantification_method == 'cell ranger arc'
				kallisto_bustools: quantification_method == 'kallisto|bustools'
				allevin: quantification_method == 'alevin'})
			.set{expression_methods}

		expression_methods.cell_ranger.dump(tag:'seurat:expression_methods.cell_ranger', pretty:true)
		expression_methods.cell_ranger_arc.dump(tag:'seurat:expression_methods.cell_ranger_arc', pretty:true)
		expression_methods.kallisto_bustools.dump(tag:'seurat:expression_methods.kallisto_bustools', pretty:true)
		expression_methods.allevin.dump(tag:'seurat:expression_methods.allevin', pretty:true)

		// make channels for the cell ranger arc quantified datasets

		unique_indetifiers   = expression_methods.cell_ranger_arc.map{it.get('unique id')}
		tags                 = expression_methods.cell_ranger_arc.map{it.get('dataset name')}
		quantification_paths = expression_methods.cell_ranger_arc.map{it.get('quantification path')}
		index_paths          = expression_methods.cell_ranger_arc.map{it.get('index path')}

		read_cell_ranger_arc_output(unique_indetifiers, tags, quantification_paths, index_paths)
}