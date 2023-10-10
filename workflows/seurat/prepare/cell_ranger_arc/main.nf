// -------------------------------------------------------------------------------------------------
// import any java/groovy libraries as required
// -------------------------------------------------------------------------------------------------

import java.nio.file.Paths

// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { cat as cat_tasks }             from '../../../../modules/tools/cat'
include { make_assay as make_rna_assay } from '../../../../modules/R/Seurat/make_assay'
include { make_object }                  from '../../../../modules/R/Seurat/make_object'
include { write_10x_counts_matrices }    from '../../../../modules/R/Seurat/write_10x_counts_matrices'

include { make_chromatin_assay } from '../../../../modules/R/Signac/make_chromatin_assay'

include { check_for_matching_key_values }     from '../../../../utilities/check_for_matching_key_values'
include { concat_workflow_emissions }         from '../../../../utilities/concat_workflow_emissions'
include { concatenate_maps_list }             from '../../../../utilities/concatenate_maps_list'
include { format_unique_key }                 from '../../../../utilities/format_unique_key'
include { make_map }                          from '../../../../utilities/make_map'
include { merge_metadata_and_process_output } from '../../../../utilities/merge_metadata_and_process_output'
include { merge_process_emissions }           from '../../../../utilities/merge_process_emissions'
include { rename_map_keys }                   from '../../../../utilities/rename_map_keys'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow cell_ranger_arc {

	take:
		parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// read the 10X cell ranger matrices into an object
		// -------------------------------------------------------------------------------------------------

		// get the unique set of quantification matrices and feature identifiers' columns
		parameters
			.map{[it.subMap('dataset id', 'quantification path'), ['accession', 'name']]}
			.transpose()
			.map{it.first() + [identifier: it.last(), 'matrix state': 'filtered']}
			.unique()
			.map{it + ['barcoded matrix path': Paths.get(it.get('quantification path').toString(), 'filtered_feature_bc_matrix')]}
			.map{it + ['tag': format_unique_key([it.get('dataset id'), it.get('matrix state'), it.get('identifier')], sep=' + ')]}
			.dump(tag: 'seurat:prepare:cell_ranger_arc:barcoded_matrices_to_read', pretty: true)
			.set{barcoded_matrices_to_read}

		// create the channels for the process to make a 10X matrix
		tags                  = barcoded_matrices_to_read.map{it.get('tag')}
		barcoded_matrix_paths = barcoded_matrices_to_read.map{it.get('barcoded matrix path')}
		identifiers           = barcoded_matrices_to_read.map{it.get('identifier')}

		// write 10x matrix of counts to rds file
		write_10x_counts_matrices(barcoded_matrices_to_read, tags, barcoded_matrix_paths, identifiers)

		// make a channel of newly created counts matrices
		merge_process_emissions(write_10x_counts_matrices, ['opt', 'counts_matrices', 'features'])
			.map{merge_metadata_and_process_output(it)}
			.dump(tag: 'seurat:prepare:cell_ranger_arc:barcoded_matrices', pretty: true)
			.set{barcoded_matrices}

		// -------------------------------------------------------------------------------------------------
		// make an RNA assay
		// -------------------------------------------------------------------------------------------------

		// create the channels for the process to make an RNA assay
		tags            = barcoded_matrices.map{it.get('tag')}
		counts_matrices = barcoded_matrices.map{it.get('counts_matrices')}

		// write rna assay to rds file
		make_rna_assay(barcoded_matrices, tags, 'Gene Expression', counts_matrices)

		// make a channel of newly created rna assays
		merge_process_emissions(make_rna_assay, ['opt', 'assay'])
			.map{merge_metadata_and_process_output(it)}
			.map{rename_map_keys(it, 'assay', sprintf('rna_assay_by_%s', it.get('identifier')))}
			.dump(tag: 'seurat:prepare:cell_ranger_arc:rna_assays_branched', pretty: true)
			.branch({
				identifier = it.get('identifier')
				accession: identifier == 'accession'
				name: identifier == 'name'})
			.set{rna_assays_branched}

		rna_assays_branched.accession.dump(tag: 'seurat:prepare:cell_ranger_arc:rna_assays_branched.accession', pretty: true)
		rna_assays_branched.name.dump(tag: 'seurat:prepare:cell_ranger_arc:rna_assays_branched.name', pretty: true)

		rna_assays_branched.accession
			.combine(rna_assays_branched.name)
			.filter{check_for_matching_key_values(it, 'quantification path')}
			.map{concatenate_maps_list(it)}
			.map{it.subMap(['quantification path', 'rna_assay_by_accession', 'rna_assay_by_name'])}
			.dump(tag: 'seurat:prepare:cell_ranger_arc:rna_assays', pretty: true)
			.set{rna_assays}

		// -------------------------------------------------------------------------------------------------
		// make an ATAC assay
		// -------------------------------------------------------------------------------------------------

		// create the channels for the process to make a chromatin assay
		barcoded_matrices
			.filter{it.get('identifier') == 'accession'}
			.combine(parameters)
			.filter{check_for_matching_key_values(it, 'dataset id')}
			.map{it.first() + it.last().get('genome parameters').subMap('granges')} 
			.map{it.subMap(['tag', 'granges', 'counts_matrices', 'quantification path'])}
			.dump(tag: 'seurat:prepare:cell_ranger_arc:chromatin_assays_to_create', pretty: true)
			.set{chromatin_assays_to_create}

		// create the channels for the process to make a chromatin assay
		tags                 = chromatin_assays_to_create.map{it.get('tag')}
		annotations          = chromatin_assays_to_create.map{it.get('granges')}
		counts_matrices      = chromatin_assays_to_create.map{it.get('counts_matrices')}
		quantification_paths = chromatin_assays_to_create.map{it.get('quantification path')}

		// write chromatin assay to rds file
		make_chromatin_assay(chromatin_assays_to_create, tags, annotations, counts_matrices, quantification_paths, 'Peaks')

		// make a channel of newly created chromatin assays
		merge_process_emissions(make_chromatin_assay, ['opt', 'assay'])
			.map{merge_metadata_and_process_output(it)}
			.map{rename_map_keys(it, 'assay', 'chromatin_assay')}
			.map{it.subMap(['quantification path', 'chromatin_assay', 'granges'])}
			.dump(tag: 'seurat:prepare:cell_ranger_arc:chromatin_assays', pretty: true)
			.set{chromatin_assays}

		// -------------------------------------------------------------------------------------------------
		// make a seurat object using rna and atac assays and the annotations
		// -------------------------------------------------------------------------------------------------

		// combine the annotations and rna and chromatin assays into a channel
		parameters
			.combine(rna_assays)
			.combine(chromatin_assays)
			.combine(barcoded_matrices.filter{it.get('identifier') == 'accession'}.map{it.subMap(['quantification path', 'features'])})
			.filter{check_for_matching_key_values(it, 'quantification path')}
			.map{concatenate_maps_list(it)}
			.map{it + [ordered_assays: it.subMap('rna_assay_by_accession', 'rna_assay_by_name').values().toList()]}
			.map{if(it.get('feature identifiers') == 'name') {it.ordered_assays = it.get('ordered_assays').reverse()} ; it}
			.map{it + [ordered_assays: it.get('ordered_assays') + [it.get('chromatin_assay')]]}
			.map{it + ['remove barcode suffixes': 'FALSE']} // should be a user parameter
			.map{it.subMap(['dataset id', 'ordered_assays', 'remove barcode suffixes', 'granges', 'features', 'dataset name'])}
			.dump(tag: 'seurat:prepare:cell_ranger_arc:objects_to_create', pretty: true)
			.set{objects_to_create}

		// create the channels for the process to make a seurat object
		tags                    = objects_to_create.map{it.get('dataset id')}
		remove_barcode_suffixes = objects_to_create.map{it.get('remove barcode suffixes')}
		assays                  = objects_to_create.map{it.get('ordered_assays')}
		misc_files              = objects_to_create.map{it.subMap(['granges', 'features']).values()}
		projects                = objects_to_create.map{it.get('dataset name')}
		assay_names             = Channel.value(['RNA', 'RNA_alt', 'ATAC'])
		misc_names              = Channel.value(['gene_models', 'features'])

		// read the two rna assays and chromatin accessibility assay into a seurat object and write to rds file
		make_object(objects_to_create, tags, remove_barcode_suffixes, assays, assay_names, misc_files, misc_names, projects)

		// add the new objects into the parameters channel
		merge_process_emissions(make_object, ['opt', 'seurat'])
			.map{merge_metadata_and_process_output(it)}
			.dump(tag: 'seurat:prepare:cell_ranger_arc:objects', pretty: true)
			.set{objects}

		// -------------------------------------------------------------------------------------------------
		// join any/all information back onto the parameters ready to emit
		// -------------------------------------------------------------------------------------------------

		parameters
			.combine(objects)
			.filter{check_for_matching_key_values(it, ['dataset id'])}
			.map{it.first() + ['seurat path': it.last().subMap(['seurat'])]}
			.dump(tag: 'seurat:prepare:cell_ranger_arc:result', pretty: true)
			.set{result}

		// -------------------------------------------------------------------------------------------------
		// make summary report for the workflow
		// -------------------------------------------------------------------------------------------------

		all_processes = [write_10x_counts_matrices, make_rna_assay, make_chromatin_assay, make_object]

		// collate the task yaml files into one
		concat_workflow_emissions(all_processes, 'task')
			.collect()
			.dump(tag: 'seurat:prepare:cell_ranger_arc:tasks', pretty: true)
			.set{tasks}

		cat_tasks([:], tasks, '*.yaml', 'tasks.yaml')

	emit:
		result = result
		tasks = tasks
}
