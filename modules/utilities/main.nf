
import static groovy.json.JsonOutput.*

def get_reserved_root_params_keys() {
	return ['project', 'shared parameters']
}

// get names of analysis stage stanzas
def get_stage_keys() {
	params
		.keySet()
		.minus(get_reserved_root_params_keys())
}

// get a map of default properties to use in analysis stage stanzas
def get_shared_stage_params() {
	params
		.get('shared parameters')
		.subMap(get_stage_keys())
}

// use shared parameters to define missing properties of analysis stage stanzas
def get_stages_params() {
	def stage_keys = get_stage_keys()
	params
		.subMap(stage_keys)
}












// get a complete set of parameters for every parameter set, filling in genomes, shared and default parameters
def get_complete_stage_parameters(stage_type=null) {
	def genomes_params = get_genomes_params()
	def shared_stage_params = get_shared_stage_params()

	get_stages_params()
		.collectEntries{stage_name, datasets -> [stage_name, datasets.collectEntries{dataset_name, parameters -> [dataset_name, ['stage name': stage_name, 'dataset name': dataset_name, 'unique id': [stage_name, dataset_name].join(' / ')] + parameters]}]}
		.collect{k,v -> v.values()}
		.flatten()
		.collect{x -> ['stage dir': make_string_directory_safe(x.get('stage name')), 'dataset dir': make_string_directory_safe(x.get('dataset name'))] + x}
		.collect{x -> add_parameter_sets(shared_stage_params.get(x.get('stage name')), x)}
		.collect{x -> convert_map_keys_to_files(x, ['index path', 'quantification path'])}
		.collect{x -> add_parameter_sets(x, ['genome parameters': genomes_params.get(x.get('genome'))])}
		.collect{x -> add_parameter_sets(x, ['md5sum': x.toString().md5().substring(0,9)])}
		.findAll{x -> x.get('stage type')==stage_type | stage_type==null}
}

// create a list of genomes used in this project
// -- returns a list of maps, one for each genome
// ++ find a genome: genomes.find{it.'genome name'=='mouse'}
// ++ add an element to a specific genome: genomes.find{it.'genome name'=='mouse'}.put('foo','bar')
def get_genomes_params() {
	recursively_get(params, ['project', 'genomes'])
		.collectEntries{genome_name, genome_parameters -> [genome_name, genome_parameters+['genome': genome_name, 'unique id': genome_name]]}
		.collectEntries{genome_name, genome_parameters -> [genome_name, genome_parameters+['md5sum': genome_parameters.toString().md5().substring(0,9)]]}
		.collectEntries{genome_name, genome_parameters -> [genome_name, convert_map_keys_to_files(genome_parameters, ['fasta files', 'gtf files', 'motifs'])]}
}

def convert_map_keys_to_files(map, keys) {
	map.keySet().intersect(keys).each{key -> map.put(key, convert_to_file(map.get(key)))}
	return map
}

def convert_to_file(value) {
	return file(value)
}

// get feature types from params
// returns a list of sample name and feature type tuples
def get_feature_types() {
	recursively_get(params, ['project', 'feature types'])
		.collect{feature_type, sample_name -> [sample_name, [feature_type]*sample_name.size()]}
		.collect{it.toList().transpose()} // maybe this should be a map
		.collectMany{it}
		.collect{['sample name':it[0], 'feature type':it[1]]}
}

def add_parameter_sets(a, b) {
	return a + b
}

// print a map as a pretty json
def print_as_json(inmap) {
	println('/// ' + '-'*246)
	print(prettyPrint(toJson(inmap)))
	println('/// ' + '-'*246)
}

// concatenate the same emitted channel from multiple workflows
def concat_workflow_emissions(channel_list, key) {
	def ch_out = channel_list.first().out.(key)
	channel_list.tail().each{ch_out=ch_out.concat(it.out.(key))}
	ch_out
}

def format_unique_key(values) {
	if(values instanceof java.util.LinkedHashMap)
		values = values.values()
	values.join(' / ')
}





///// the wild west

def pluck_parameter(map, path, missing) {
	def key = path.get(0)
	def submap = map.get(key, missing)

	// if there are elements in the path
	if(path.size() > 1) {
		// pluck the next element from the map
		return pluck_parameter(submap, path.tail(), missing)
	} else {
		// return the plucked element or the missing value
		return submap
	}
}

def make_string_directory_safe(String string) {
	string.replaceAll("[^a-zA-Z0-9-_\\.]", "_");
}

def recursively_get(map, path, missing='missing') {
	def key = path.get(0)
	def submap = map.get(key, missing)

	// if there are elements in the path
	if(path.size() > 1) {
		// pluck the next element from the map
		return recursively_get(submap, path.tail(), missing)
	} else {
		// return the plucked element or the missing value
		return submap
	}
}

def val_to_path(val) {
	return file(val)
}

def rename_map_keys(map, from, to) {
	from = from.class==String ? [from] : from
	to = to.class==String ? [to] : to
	[from, to]
		.transpose().each{
			map.put(it[1], map.get(it[0]))
			map.remove(it[0])}
	return map
}

def make_map(values, keys) {
	[keys, values]
		.transpose()
		.collectEntries()
}

// just use flatten for lists of lists of scalars
def concatenate_maps_list(a) {
	if(a.every{it instanceof java.util.ArrayList})
		println('[concatenate_maps_list] given a list of ArrayLists! maybe use flatten?')

	def b = a.first()
	a.tail()
		.each{b=b+it}
	return b
}


def check_for_matching_key_values(x, key) {
	def values = x.collect{it.get(key)}.minus((null))
	values.size()>1 && values.every{it==values.first()}
}
