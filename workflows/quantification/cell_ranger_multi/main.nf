
// -------------------------------------------------------------------------------------------------
// specify modules relevant to this workflow
// -------------------------------------------------------------------------------------------------

include { cat as combine_task_records } from '../../../modules/tools/cat'
include { count }                       from '../../../modules/cell_ranger_multi/count'
include { make_input_csv }              from '../../../modules/cell_ranger_multi/make_input_csv'
include { mkref }                       from '../../../modules/cell_ranger_arc/mkref'

include { check_for_matching_key_values }     from '../../../utilities/check_for_matching_key_values'
include { concat_workflow_emissions }         from '../../../utilities/concat_workflow_emissions'
include { convert_to_files }                  from '../../../utilities/convert_map_keys_to_files'
include { find_key_of_value }                 from '../../../utilities/find_key_of_value'
include { make_map }                          from '../../../utilities/make_map'
include { merge_metadata_and_process_output } from '../../../utilities/merge_metadata_and_process_output'
include { merge_process_emissions }           from '../../../utilities/merge_process_emissions'
include { rename_map_keys }                   from '../../../utilities/rename_map_keys'

// -------------------------------------------------------------------------------------------------
// define the workflow
// -------------------------------------------------------------------------------------------------

workflow cell_ranger_multi {

	take:
		parameters

	main:
		// -------------------------------------------------------------------------------------------------
		// create missing cell ranger arc indexes
		// -------------------------------------------------------------------------------------------------

//		// branch parameters into two channels: {missing,provided} according to the presence of the 'index path' key
//		parameters
//			.map{it.get('genome parameters').subMap(['id', 'organism', 'non-nuclear contigs', 'motifs file', 'fasta file', 'gtf file']) + it.subMap('index path')}
//			.unique()
//			.branch{
//				def index_provided = it.containsKey('index path')
//				provided: index_provided == true
//				missing: index_provided == false}
//			.set{genome_indexes}
//
//		genome_indexes.missing.dump(tag: 'quantification:cell_ranger_arc:genome_indexes.missing', pretty: true)
//		genome_indexes.provided.dump(tag: 'quantification:cell_ranger_arc:genome_indexes.provided', pretty: true)
//
//		// make channels of parameters for genomes that need indexes to be created
//		tags                = genome_indexes.missing.map{it.get('id')}
//		organisms           = genome_indexes.missing.map{it.get('organism')}
//		assemblies          = genome_indexes.missing.map{it.get('id')}
//		non_nuclear_contigs = genome_indexes.missing.map{it.get('non-nuclear contigs')}
//		motifs_files        = genome_indexes.missing.map{it.get('motifs file')}
//		fasta_files         = genome_indexes.missing.map{it.get('fasta file')}
//		gtf_files           = genome_indexes.missing.map{it.get('gtf file')}
//
//		// create cell ranger arc indexes
//		mkref(genome_indexes.missing, tags, organisms, assemblies, non_nuclear_contigs, motifs_files, fasta_files, gtf_files)
//
//		// make a channel of newly created genome indexes, each defined in a map
//		merge_process_emissions(mkref, ['opt', 'path'])
//			.map{rename_map_keys(it, 'path', 'index path')}
//			.map{merge_metadata_and_process_output(it)}
//			.concat(genome_indexes.provided)
//			.dump(tag: 'quantification:cell_ranger_arc:index_paths', pretty: true)
//			.set{index_paths}

		// -------------------------------------------------------------------------------------------------
		// make a sample sheet of all samples in any dataset that should be quantified
		// -------------------------------------------------------------------------------------------------
		
		parameters
			.map{[[it.get('limsid')].flatten().join('|'), it]}
			.groupTuple(by: 0)
			.map{it.last()}
			.map{[adt_set_path:   it.collect{it.getOrDefault('adt set path', file('.undefined'))}.unique().first(), // defaults could be moduleDir + 'assets' + 'file.csv'
			      barcodes:       it.collect{it.get('barcode')},
			      dataset_ids:    it.collect{it.get('dataset id')},
			      descriptions:   it.collect{it.get('description')},
			      fastq_paths:    it.collect{it.get('fastq paths')}.flatten().unique(), // are these risky?
			      feature_types:  it.first().get('feature types'),
			      hto_set_path:   it.collect{it.getOrDefault('hto set path', file('.undefined'))}.unique().first(),
			      index_path:     it.collect{it.get('index path')}.unique().first(),
			      limsid:         it.collect{it.get('limsid')}.flatten().unique(),
			      probe_set_path: it.collect{it.getOrDefault('probe set path', file('.undefined'))}.unique().first(),
			      project_type:   it.first().get('project parameters').get('type'),
			      vdj_index_path: it.collect{it.getOrDefault('vdj index path', file('.undefined'))}.unique().first()]}
			.map{it + [feature_types: [it.get('limsid')].flatten().collect{x -> find_key_of_value(it.get('feature_types'), x)}]}
			.map{it + [fastq_paths: convert_to_files(it.get('fastq_paths'))]}
			.dump(tag: 'quantification:cell_ranger_multi:configuration_params', pretty: true)
			.set{configuration_params}

		// make channels to create the libraries csv file that cell ranger arc count expects
		adt_set_paths   = configuration_params.map{it.get('adt_set_path')}
		barcodes        = configuration_params.map{it.get('barcodes')}
		dataset_ids     = configuration_params.map{it.get('dataset_ids')}
		descriptions    = configuration_params.map{it.get('descriptions')}
		fastq_paths     = configuration_params.map{it.get('fastq_paths')}
		feature_types   = configuration_params.map{it.get('feature_types')}
		hto_set_paths   = configuration_params.map{it.get('hto_set_path')}
		index_paths     = configuration_params.map{it.get('index_path')}
		limsids         = configuration_params.map{it.get('limsid')}
		probe_set_paths = configuration_params.map{it.get('probe_set_path')}
		project_types   = configuration_params.map{it.get('project_type')}
		vdj_index_paths = configuration_params.map{it.get('vdj_index_path')}

		// make a sample sheet for each cell ranger multi task
		make_input_csv(configuration_params,
		               project_types, limsids, dataset_ids, descriptions, barcodes, feature_types,
		               fastq_paths, index_paths, vdj_index_paths,
		               probe_set_paths, adt_set_paths, hto_set_paths)

		// make a channel of newly created cell ranger multi configuration files
		merge_process_emissions(make_input_csv, ['opt', 'input_csv'])
			.map{it.get('opt') + [config_file: it.get('input_csv')]}
			.dump(tag: 'quantification:cell_ranger_multi:quantification_configs', pretty: true)
			.set{quantification_configs}

		// -------------------------------------------------------------------------------------------------
		// quantify (possibly multiplexed) libraries into datasets
		// -------------------------------------------------------------------------------------------------

		// make a channel containing all information for the quantification process
		quantification_configs
			.map{it.subMap(['config_file', 'limsid', 'dataset_ids'])}
			.map{it + [output_dir: it.get('limsid').sort{it - ~/^\w+\d+A/ as int}.join('-')]}
			.dump(tag: 'quantification:cell_ranger_multi:libraries_to_quantify', pretty: true)
			.set{libraries_to_quantify}

		// make channels of parameters for libraries that need to be analysed
		output_dirs   = libraries_to_quantify.map{it.get('output_dir')}
		config_files  = libraries_to_quantify.map{it.get('config_file')}
		dataset_ids   = libraries_to_quantify.map{it.get('dataset_ids')}

		// quantify the libraries into datasets
		count(libraries_to_quantify, output_dirs, dataset_ids, config_files)

		// make a channel of newly quantified datasets, each defined in a map
		merge_process_emissions(count, ['opt', 'multi_quantification_path', 'per_sample_quantification_path'])
			.map{it + ['quantification path': make_map([it.get('per_sample_quantification_path')].flatten(), [it.get('per_sample_quantification_path')].flatten{it.getFileName().toString()})]}
			.map{make_map([it]*it.get('per_sample_quantification_path').size(), [it.get('per_sample_quantification_path')].flatten{it.getFileName().toString()})}
			.map{it.collectEntries{k,v -> [k, v + ['dataset id': k, 'quantification path': v.get('quantification path').get(k)]]}}
			.map{it.collectEntries{k,v -> [k, v + ['cell ranger multi config': v.get('opt').get('config_file')]]}}
			.map{it.collectEntries{k,v -> [k, v.findAll{!['opt','per_sample_quantification_path'].contains(it.key)}]}}
			.dump(tag: 'quantification:cell_ranger_multi:quantified_datasets', pretty: true)
			.set{quantified_datasets}

		// -------------------------------------------------------------------------------------------------
		// join any/all information back onto the parameters ready to emit
		// -------------------------------------------------------------------------------------------------

		parameters
			.combine(quantified_datasets)
			.map{it.first() + it.last().get(it.first().get('dataset id'), ['quantification path': '.undefined'])}
			.filter{it.get('quantification path') != '.undefined'}
			.map{it + ['quantification method': 'cell_ranger_multi']}
			.dump(tag: 'quantification:cell_ranger_arc:result', pretty: true)
			.set{result}

		// -------------------------------------------------------------------------------------------------
		// make summary report for the workflow
		// -------------------------------------------------------------------------------------------------

//		all_processes = [mkref, count]
//
//		// collate the task yaml files into one
//		concat_workflow_emissions(all_processes, 'task')
//			.collect()
//			.dump(tag: 'quantification:cell_ranger_arc:tasks', pretty: true)
//			.set{tasks}
//
//		combine_task_records([:], tasks, '*.yaml', 'tasks.yaml', 'true')

	emit:
		result = 'result'
		tasks = 'tasks'
//		result = result
//		tasks = tasks
}
