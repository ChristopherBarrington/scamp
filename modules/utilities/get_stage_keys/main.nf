// get names of analysis stage stanzas

def get_stage_keys() {
	def reserved_root_params_keys = ['project', 'shared parameters']
	params
		.keySet()
		.minus(reserved_root_params_keys)
}
