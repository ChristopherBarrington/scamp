
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

include { check_for_matching_key_values } from '../../modules/utilities/check_for_matching_key_values'
include { concat_workflow_emissions }     from '../../modules/utilities/concat_workflow_emissions'
include { concatenate_maps_list }         from '../../modules/utilities/concatenate_maps_list'
include { format_unique_key }             from '../../modules/utilities/format_unique_key'
include { make_map }                      from '../../modules/utilities/make_map'
include { merge_process_emissions }       from '../../modules/utilities/merge_process_emissions'
include { rename_map_keys }               from '../../modules/utilities/rename_map_keys'

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
		// read the 10X cell ranger matrices into an object
		// -------------------------------------------------------------------------------------------------

		// get the unique set of quantification matrices and feature identifiers' columns
		expression_methods.cell_ranger_arc
			.map{it.subMap(['gene identifiers', 'quantification path'])}
			.unique()
			.map{it + ['barcoded matrix path': Paths.get(it.get('quantification path').toString(), 'filtered_feature_bc_matrix')]}
			.map{it + ['uid': it.toString().md5().substring(0, 6)]}
			.dump(tag:'seurat:cell_ranger_arc:barcoded_matrices_to_read', pretty:true)
			.set{barcoded_matrices_to_read}

		// create the channels for the process to make an RNA assay
		unique_identifiers    = barcoded_matrices_to_read.map{it.get('uid')}
		tags                  = barcoded_matrices_to_read.map{it.get('uid')}
		barcoded_matrix_paths = barcoded_matrices_to_read.map{it.get('barcoded matrix path')}
		feature_identifiers   = barcoded_matrices_to_read.map{it.get('gene identifiers')}

		write_10x_counts_matrices(unique_identifiers, tags, barcoded_matrix_paths, feature_identifiers)

		// make a channel of newly created counts matrices
		merge_process_emissions(write_10x_counts_matrices, ['uid', 'counts_matrices', 'features'])
			.map{x -> rename_map_keys(x, 'counts_matrices', 'counts matrices')}
			.combine(barcoded_matrices_to_read)
			.filter{check_for_matching_key_values(it, 'uid')}
			.map{concatenate_maps_list(it)}
			.map{it.findAll{it.key != 'uid'}}
			.dump(tag:'seurat:cell_ranger_arc:barcoded_matrices', pretty:true)
			.set{barcoded_matrices}

		// -------------------------------------------------------------------------------------------------
		// make an RNA assay
		// -------------------------------------------------------------------------------------------------

		// combine the counts matrices into a channel
		expression_methods.cell_ranger_arc
			.combine(barcoded_matrices)
			.filter{check_for_matching_key_values(it, 'gene identifiers')}
			.filter{check_for_matching_key_values(it, 'quantification path')}
			.map{it.first() + it.last().subMap('matrices path', 'counts matrices')}
			.dump(tag:'seurat:cell_ranger_arc:rna_assays_to_create', pretty:true)
			.set{rna_assays_to_create}

		// create the channels for the process to make an RNA assay
		unique_identifiers  = rna_assays_to_create.map{it.get('unique id')}
		tags                = rna_assays_to_create.map{it.get('dataset name')}
		counts_matrices = rna_assays_to_create.map{it.get('counts matrices')}

		make_rna_assay(unique_identifiers, tags, 'Gene Expression', counts_matrices)

		// make a channel of newly created rna assays
		merge_process_emissions(make_rna_assay, ['uid', 'assay'])
			.map{rename_map_keys(it, ['uid', 'assay'], ['unique id', 'rna assay'])}
			.dump(tag:'seurat:cell_ranger_arc:rna_assays', pretty:true)
			.set{rna_assays}

		// -------------------------------------------------------------------------------------------------
		// make GRanges objects for gene annotations of the genomes
		// -------------------------------------------------------------------------------------------------

		// create the channels for the process to make GRanges objects using Cell Ranger ARC indexes
		expression_methods.cell_ranger_arc
			.map{it.subMap(['genome', 'index path'])}
			.unique()
			.map{it + [uid: it.toString().md5()]}
			.map{it + [gtf: Paths.get(it.get('index path').toString(), 'genes', 'genes.gtf.gz')]}
			.map{it + [fai: Paths.get(it.get('index path').toString(), 'fasta', 'genome.fa.fai')]}
			.dump(tag:'seurat:cell_ranger_arc:gtf_files_to_convert_to_granges', pretty:true)
			.set{gtf_files_to_convert_to_granges}

		unique_identifiers = gtf_files_to_convert_to_granges.map{it.get('uid')}
		tags               = gtf_files_to_convert_to_granges.map{it.get('genome')}
		genome_names       = gtf_files_to_convert_to_granges.map{it.get('genome')}
		gtf_files          = gtf_files_to_convert_to_granges.map{it.get('gtf')}
		fai_files          = gtf_files_to_convert_to_granges.map{it.get('fai')}

		convert_gtf_to_granges(unique_identifiers, tags, genome_names, gtf_files, fai_files)

		// make a channel of newly created GRanges rds files
		merge_process_emissions(convert_gtf_to_granges, ['uid', 'granges'])
			.map{x -> rename_map_keys(x, 'granges' ,'genes granges')}
			.combine(gtf_files_to_convert_to_granges)
			.filter{it.first().get('uid') == it.last().get('uid')}
			.map{it.first() + it.last()}
			.map{it.subMap(['genome', 'index path', 'genes granges'])}
			.dump(tag:'seurat:cell_ranger_arc:granges_files', pretty:true)
			.set{granges_files}

		// -------------------------------------------------------------------------------------------------
		// make an ATAC assay
		// -------------------------------------------------------------------------------------------------

		// combine annotations and quantifications
		expression_methods.cell_ranger_arc
			.combine(granges_files)
			.filter{check_for_matching_key_values(it, 'genome')}
			.filter{check_for_matching_key_values(it, 'index path')}
			.map{it.first() + it.last().subMap('genes granges')}
			.combine(barcoded_matrices)
			.filter{check_for_matching_key_values(it, 'gene identifiers')}
			.filter{check_for_matching_key_values(it, 'quantification path')}
			.map{it.first() + it.last().subMap('matrices path', 'counts matrices')}
			.dump(tag:'seurat:cell_ranger_arc:chromatin_assays_to_create', pretty:true)
			.set{chromatin_assays_to_create}

		// create the channels for the process to make a chromatin assay
		unique_identifiers   = chromatin_assays_to_create.map{it.get('unique id')}
		tags                 = chromatin_assays_to_create.map{it.get('dataset name')}
		annotations          = chromatin_assays_to_create.map{it.get('genes granges')}
		counts_matrices      = chromatin_assays_to_create.map{it.get('counts matrices')}
		quantification_paths = chromatin_assays_to_create.map{it.get('quantification path')}

		make_chromatin_assay(unique_identifiers, tags, annotations, counts_matrices, quantification_paths, 'Peaks')

		// make a channel of newly created chromatin assays
		merge_process_emissions(make_chromatin_assay, ['uid', 'assay'])
			.map{rename_map_keys(it, ['uid', 'assay'], ['unique id', 'chromatin assay'])}
			.dump(tag:'seurat:cell_ranger_arc:chromatin_assays', pretty:true)
			.set{chromatin_assays}

		// -------------------------------------------------------------------------------------------------
		// make a seurat object using rna and atac assays and the annotations
		// -------------------------------------------------------------------------------------------------

		// combine the annotations and rna and chromatin assays into a channel
		expression_methods.cell_ranger_arc
			.combine(granges_files)
			.combine(rna_assays)
			.combine(chromatin_assays)
			.filter{check_for_matching_key_values(it, 'genome')}
			.filter{check_for_matching_key_values(it, 'unique id')}
			.map{concatenate_maps_list(it)}
			.combine(barcoded_matrices)
			.filter{check_for_matching_key_values(it, 'gene identifiers')}
			.filter{check_for_matching_key_values(it, 'quantification path')}
			.map{concatenate_maps_list(it)}
			.dump(tag:'seurat:cell_ranger_arc:seurat_objects_to_create', pretty:true)
			.set{seurat_objects_to_create}

		// create the channels for the process to make a seurat object

		uids         = seurat_objects_to_create.map{it.get('unique id')}
		tags         = seurat_objects_to_create.map{it.get('dataset name')}
		assays       = seurat_objects_to_create.map{it.subMap(['rna assay', 'chromatin assay']).values()}
		assay_names  = seurat_objects_to_create.map{['RNA', 'ATAC']}
		dataset_tags = seurat_objects_to_create.map{it.get('dataset tag')}
		misc_files   = seurat_objects_to_create.map{it.subMap(['genes granges', 'features']).values()}
		misc_names   = seurat_objects_to_create.map{['gene_models', 'features']}
		projects     = seurat_objects_to_create.map{it.get('dataset name')}

		make_seurat_object(uids, tags, assays, assay_names, dataset_tags, misc_files, misc_names, projects)

		// add the new objects into the parameters channel
		merge_process_emissions(make_seurat_object, ['uid', 'seurat'])
			.map{rename_map_keys(it, ['uid', 'seurat'], ['unique id', 'seurat path'])}
			.combine(seurat_objects_to_create)
			.filter{check_for_matching_key_values(it, 'unique id')}
			.map{it.last() + it.first().subMap('seurat path')}
			.dump(tag:'seurat:cell_ranger_arc:seurat_objects', pretty:true)
			.set{seurat_objects}

		// -------------------------------------------------------------------------------------------------
		// make summary report for cell ranger arc stage
		// -------------------------------------------------------------------------------------------------

		all_processes = [write_10x_counts_matrices, make_rna_assay, convert_gtf_to_granges, make_chromatin_assay, make_seurat_object]

		// collate the software version yaml files into one
		concat_workflow_emissions(all_processes, 'versions')
			.collect()
			.set{versions}

		merge_software_versions(versions)

		// collate the software version yaml files into one
		concat_workflow_emissions(all_processes, 'task')
			.collect()
			.set{task_properties}

		merge_task_properties(task_properties)

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
