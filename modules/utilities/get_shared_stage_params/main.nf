// get a map of default properties to use in analysis stage stanzas

include { convert_map_keys_to_files } from '../convert_map_keys_to_files'
include { get_stage_keys } from '../get_stage_keys'

def get_shared_stage_params() {
	params
		.get('shared parameters')
		.subMap(get_stage_keys())
		.collectEntries{k, v -> [k, convert_map_keys_to_files(v, ['index path', 'quantification path', 'fastq paths'])]}
}
