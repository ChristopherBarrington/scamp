// get a complete set of parameters for every parameter set, filling in genomes, shared and default parameters

include { convert_map_keys_to_files }  from '../convert_map_keys_to_files'
include { get_genomes_params }         from '../get_genomes_params'
include { get_shared_stage_params }    from '../get_shared_stage_params'
include { get_stages_params }          from '../get_stages_params'
include { make_string_directory_safe } from '../make_string_directory_safe'

def get_complete_stage_parameters(stage_type=null) {
	def genomes_params = get_genomes_params()
	def shared_stage_params = get_shared_stage_params()

	get_stages_params()
		.collectEntries{stage_key, datasets -> [stage_key, datasets.collectEntries{dataset_key, parameters -> [dataset_key, ['stage key': stage_key, 'dataset key': dataset_key,
		                                                                                                                     'unique id': [stage_key, dataset_key].join(' / ')] + parameters]}]}
		.collect{k,v -> v.values()}
		.flatten()
		.collect{it + ['stage name': it.get('stage name', it.get('stage key')),
		               'dataset name': it.get('dataset name', it.get('dataset key'))]}
		.collect{it + ['stage id': make_string_directory_safe(it.get('stage id', it.get('stage name'))),
		               'dataset id': make_string_directory_safe(it.get('dataset id', it.get('dataset name')))]}
		.collect{x -> add_parameter_sets(shared_stage_params.get(x.get('stage key')), x)}
		.collect{x -> convert_map_keys_to_files(x, ['index path', 'quantification path', 'fastq paths'])}
		.collect{x -> add_parameter_sets(x, ['genome parameters': genomes_params.get(x.get('genome'))])}
		// .collect{x -> add_parameter_sets(x, ['md5 checksum': x.toString().md5()])}
		.findAll{x -> x.get('stage type')==stage_type | stage_type==null}
}

def add_parameter_sets(a, b) {
  return a + b
}
