// get a complete set of parameters for every parameter set, filling in genomes, shared and default parameters

include { convert_map_keys_to_files } from '../convert_map_keys_to_files'
include { get_genomes_params } from '../get_genomes_params'
include { get_shared_stage_params } from '../get_shared_stage_params'
include { get_stages_params } from '../get_stages_params'
include { make_string_directory_safe } from '../make_string_directory_safe'

def get_complete_stage_parameters(stage_type=null) {
  def genomes_params = get_genomes_params()
  def shared_stage_params = get_shared_stage_params()

  get_stages_params()
    .collectEntries{stage_name, datasets -> [stage_name, datasets.collectEntries{dataset_name, parameters -> [dataset_name, ['stage name': stage_name, 'dataset name': dataset_name, 'unique id': [stage_name, dataset_name].join(' / ')] + parameters]}]}
    .collect{k,v -> v.values()}
    .flatten()
    .collect{x -> ['stage dir': make_string_directory_safe(x.get('stage name')), 'dataset dir': make_string_directory_safe(x.get('dataset name'))] + x}
    .collect{x -> add_parameter_sets(shared_stage_params.get(x.get('stage name')), x)}
    .collect{x -> convert_map_keys_to_files(x, ['index path', 'quantification path', 'fastq_files'])}
    .collect{x -> add_parameter_sets(x, ['genome parameters': genomes_params.get(x.get('genome'))])}
    .collect{x -> add_parameter_sets(x, ['md5sum': x.toString().md5()])}
    .findAll{x -> x.get('stage type')==stage_type | stage_type==null}
}

def add_parameter_sets(a, b) {
  return a + b
}
