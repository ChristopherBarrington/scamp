// use shared parameters to define missing properties of analysis stage stanzas

include { get_stage_keys } from '../get_stage_keys'

def get_stages_params() {
	params.subMap(get_stage_keys())
}
