
// -------------------------------------------------------------------------------------------------
// import any java/groovy libraries as required
// -------------------------------------------------------------------------------------------------

import java.nio.file.Paths

// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { convert_gtf_to_granges } from '../../modules/R/GenomicRanges/convert_gtf_to_granges'

include { make_assay as make_rna_assay }      from '../../modules/R/Seurat/make_assay'
include { make_object as make_seurat_object } from '../../modules/R/Seurat/make_object'
include { write_10x_counts_matrices }         from '../../modules/R/Seurat/write_10x_counts_matrices'

include { make_chromatin_assay } from '../../modules/R/Signac/make_chromatin_assay'

include { check_for_matching_key_values }     from '../../modules/utilities/check_for_matching_key_values'
include { concat_workflow_emissions }         from '../../modules/utilities/concat_workflow_emissions'
include { concatenate_maps_list }             from '../../modules/utilities/concatenate_maps_list'
include { format_unique_key }                 from '../../modules/utilities/format_unique_key'
include { make_map }                          from '../../modules/utilities/make_map'
include { merge_metadata_and_process_output } from '../../modules/utilities/merge_metadata_and_process_output'
include { merge_process_emissions }           from '../../modules/utilities/merge_process_emissions'
include { remove_keys_from_map }              from '../../modules/utilities/remove_keys_from_map'
include { rename_map_keys }                   from '../../modules/utilities/rename_map_keys'

include { merge_yaml as merge_software_versions } from '../../modules/yq/merge_yaml'
include { merge_yaml as merge_task_properties }   from '../../modules/yq/merge_yaml'

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
		// split quantified datasets into quantification method channels
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

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// TODO: this should be a cell ranger arc-specific subworkflow
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

		// -------------------------------------------------------------------------------------------------
		// make GRanges objects for gene annotations of the genomes
		// -------------------------------------------------------------------------------------------------

		// create the channels for the process to make GRanges objects using Cell Ranger ARC indexes
		expression_methods.cell_ranger_arc
			.map{it.subMap(['genome', 'index path'])}
			.unique()
			.map{it + [gtf: Paths.get(it.get('index path').toString(), 'genes', 'genes.gtf.gz')]}
			.map{it + [fai: Paths.get(it.get('index path').toString(), 'fasta', 'genome.fa.fai')]}
			.dump(tag:'seurat:cell_ranger_arc:gtf_files_to_convert_to_granges', pretty:true)
			.set{gtf_files_to_convert_to_granges}

		tags      = gtf_files_to_convert_to_granges.map{it.get('genome')}
		genomes   = gtf_files_to_convert_to_granges.map{it.get('genome')}
		gtf_files = gtf_files_to_convert_to_granges.map{it.get('gtf')}
		fai_files = gtf_files_to_convert_to_granges.map{it.get('fai')}

		convert_gtf_to_granges(gtf_files_to_convert_to_granges, tags, genomes, gtf_files, fai_files)

		// make a channel of newly created GRanges rds files
		merge_process_emissions(convert_gtf_to_granges, ['metadata', 'granges'])
			.map{merge_metadata_and_process_output(it)}
			.dump(tag:'seurat:cell_ranger_arc:granges_files', pretty:true)
			.set{granges_files}

		// -------------------------------------------------------------------------------------------------
		// read the 10X cell ranger matrices into an object
		// -------------------------------------------------------------------------------------------------

		// get the unique set of quantification matrices and feature identifiers' columns
		expression_methods.cell_ranger_arc
			.map{[it.subMap('index path', 'quantification path'), ['accession','name']]}
			.transpose()
			.map{it.first() + [identifier:it.last()]}
			.unique()
			.map{it + ['barcoded matrix path': Paths.get(it.get('quantification path').toString(), 'filtered_feature_bc_matrix')]}
			.map{it + ['tag': it.toString().md5().take(9)]}
			// .map{it + ['tag': it.get('quantification path').toString().takeRight(33)]}
			.dump(tag:'seurat:cell_ranger_arc:barcoded_matrices_to_read', pretty:true)
			.set{barcoded_matrices_to_read}

		// create the channels for the process to make a 10X matrix
		tags                  = barcoded_matrices_to_read.map{it.get('tag')}
		barcoded_matrix_paths = barcoded_matrices_to_read.map{it.get('barcoded matrix path')}
		identifiers           = barcoded_matrices_to_read.map{it.get('identifier')}

		write_10x_counts_matrices(barcoded_matrices_to_read, tags, barcoded_matrix_paths, identifiers)

		// make a channel of newly created counts matrices
		merge_process_emissions(write_10x_counts_matrices, ['metadata', 'counts_matrices', 'features'])
			.map{merge_metadata_and_process_output(it)}
			.dump(tag:'seurat:cell_ranger_arc:barcoded_matrices', pretty:true)
			.set{barcoded_matrices}

		// -------------------------------------------------------------------------------------------------
		// make an RNA assay
		// -------------------------------------------------------------------------------------------------

		// create the channels for the process to make an RNA assay
		tags            = barcoded_matrices.map{it.get('tag')}
		counts_matrices = barcoded_matrices.map{it.get('counts_matrices')}

		make_rna_assay(barcoded_matrices, tags, 'Gene Expression', counts_matrices)

		// make a channel of newly created rna assays
		merge_process_emissions(make_rna_assay, ['metadata', 'assay'])
			.map{merge_metadata_and_process_output(it)}
			.map{rename_map_keys(it, 'assay', sprintf('rna_assay_by_%s', it.get('identifier')))}
			.dump(tag:'seurat:cell_ranger_arc:rna_assays_branched', pretty:true)
			.branch({
				identifier = it.get('identifier')
				accession: identifier == 'accession'
				name: identifier == 'name'})
			.set{rna_assays_branched}

		rna_assays_branched.accession
			.combine(rna_assays_branched.name)
			.filter{check_for_matching_key_values(it, 'quantification path')}
			.map{concatenate_maps_list(it)}
			.map{it.subMap(['quantification path', 'rna_assay_by_accession', 'rna_assay_by_name'])}
			.dump(tag:'seurat:cell_ranger_arc:rna_assays', pretty:true)
			.set{rna_assays}

		// -------------------------------------------------------------------------------------------------
		// make summary report for cell ranger arc stage
		// make an ATAC assay
		// -------------------------------------------------------------------------------------------------

		all_processes = [write_10x_counts_matrices, make_rna_assay, convert_gtf_to_granges, make_chromatin_assay, make_seurat_object]
		// create the channels for the process to make a chromatin assay
		expression_methods.cell_ranger_arc
			.map{it.subMap('dataset name', 'genome', 'quantification path')}
			.unique()
			.combine(granges_files.map{it.subMap(['genome','granges'])})
			.combine(barcoded_matrices.filter{it.get('identifier') == 'accession'})
			.filter{check_for_matching_key_values(it, 'genome')}
			.filter{check_for_matching_key_values(it, 'quantification path')}
			.map{concatenate_maps_list(it).subMap(['dataset name', 'granges', 'counts_matrices', 'quantification path'])}
		barcoded_matrices
			.filter{it.get('identifier') == 'accession'}
			.combine(granges_files.map{it.subMap(['index path','granges'])})
			.filter{check_for_matching_key_values(it, 'index path')}
			.map{concatenate_maps_list(it)}
			.map{it.subMap(['tag', 'granges', 'counts_matrices', 'quantification path'])}
			.dump(tag:'seurat:cell_ranger_arc:chromatin_assays_to_create', pretty:true)
			.set{chromatin_assays_to_create}

		// collate the software version yaml files into one
		concat_workflow_emissions(all_processes, 'versions')
			.collect()
			.set{versions}
		// create the channels for the process to make a chromatin assay
		tags                 = chromatin_assays_to_create.map{it.get('dataset name')}
		tags                 = chromatin_assays_to_create.map{it.get('tag')}
		annotations          = chromatin_assays_to_create.map{it.get('granges')}
		counts_matrices      = chromatin_assays_to_create.map{it.get('counts_matrices')}
		quantification_paths = chromatin_assays_to_create.map{it.get('quantification path')}

		make_chromatin_assay(chromatin_assays_to_create, tags, annotations, counts_matrices, quantification_paths, 'Peaks')

		// collate the software version yaml files into one
		concat_workflow_emissions(all_processes, 'task')
			.collect()
			.set{task_properties}
			.map{it.subMap(['quantification path', 'rna assay by accession', 'rna assay by name'])}
			.dump(tag:'seurat:cell_ranger_arc:rna_assays', pretty:true)
			.set{rna_assays}
		// make a channel of newly created chromatin assays
		merge_process_emissions(make_chromatin_assay, ['metadata', 'assay'])
			.map{merge_metadata_and_process_output(it)}
			.map{rename_map_keys(it, 'assay', 'chromatin_assay')}
			.map{it.subMap(['quantification path', 'chromatin_assay'])}
			.dump(tag:'seurat:cell_ranger_arc:chromatin_assays', pretty:true)
			.set{chromatin_assays}

		merge_task_properties(task_properties)
		// -------------------------------------------------------------------------------------------------
		// make a seurat object using rna and atac assays and the annotations
		// -------------------------------------------------------------------------------------------------

		// combine the annotations and rna and chromatin assays into a channel
		expression_methods.cell_ranger_arc
			.combine(rna_assays)
			.combine(chromatin_assays)
			.combine(granges_files.map{it.subMap(['genome', 'index path', 'granges'])})
			.combine(barcoded_matrices.filter{it.get('identifier') == 'accession'}.map{it.subMap(['index path', 'quantification path', 'features'])})
			.filter{check_for_matching_key_values(it, 'genome')}
			.filter{check_for_matching_key_values(it, 'index path')}
			.filter{check_for_matching_key_values(it, 'quantification path')}
			.map{concatenate_maps_list(it)}
			.dump(tag:'seurat:cell_ranger_arc:seurat_objects_to_create', pretty:true)
			.set{seurat_objects_to_create}

		// create the channels for the process to make a seurat object
		tags         = seurat_objects_to_create.map{it.get('dataset name')}
		assays       = seurat_objects_to_create.map{it.subMap(['rna_assay_by_accession', 'rna_assay_by_name', 'chromatin_assay']).values()}
		assay_names  = seurat_objects_to_create.map{['RNA', 'RNA_alt', 'ATAC']}
		dataset_tags = seurat_objects_to_create.map{it.get('dataset tag')}
		misc_files   = seurat_objects_to_create.map{it.subMap(['granges', 'features']).values()}
		misc_names   = seurat_objects_to_create.map{['gene_models', 'features']}
		projects     = seurat_objects_to_create.map{it.get('dataset name')}

		make_seurat_object(seurat_objects_to_create, tags, assays, assay_names, dataset_tags, misc_files, misc_names, projects)

		// add the new objects into the parameters channel
		merge_process_emissions(make_seurat_object, ['metadata', 'seurat'])
			.map{merge_metadata_and_process_output(it)}
			.dump(tag:'seurat:cell_ranger_arc:seurat_objects', pretty:true)
			.set{seurat_objects}


		// -------------------------------------------------------------------------------------------------
		// render a report for this part of the analysis
		// -------------------------------------------------------------------------------------------------

		// TODO: add process to render a chapter of a report

	emit:
		subworkflows         = seurat_objects.count().flatMap{['cell ranger arc + seurat'].multiply(it)}
		unique_ids           = seurat_objects.flatMap{it.get('unique id')}
		stage_names          = seurat_objects.flatMap{it.get('stage name')}
		dataset_names        = seurat_objects.flatMap{it.get('dataset name')}
		seurat_paths         = seurat_objects.flatMap{it.get('seurat path')}
		report               = channel.of('report.document')

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
}
