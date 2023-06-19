// get a complete set of parameters for every parameter set, filling in genomes, shared and default parameters

include { convert_map_keys_to_files }  from '../convert_map_keys_to_files'
include { make_string_directory_safe } from '../make_string_directory_safe'
include { pluck }                      from '../pluck'
include { remove_keys_from_map }       from '../remove_keys_from_map'

def get_complete_analysis_parameters(stage=null) {
	def genomes_params = get_genomes_params()
	def default_dataset_params = get_default_dataset_params()
	def possible_file_keys = get_possible_file_keys()

	get_analysis_params()
		// remove the default dataset parameters
		// - these are collected above
		.collectEntries{analysis_key, datasets -> [analysis_key, remove_keys_from_map(datasets, '_defaults')]}

		// add key information to the parameters stanza
		// - copy across: analysis and dataset key
		// - make an unique identifier for the parameter set in the analysis+dataset keys
		.collectEntries{analysis_key, datasets -> [analysis_key, datasets.collectEntries{dataset_key, parameters -> [dataset_key, ['analysis key': analysis_key, 'dataset key': dataset_key, 'unique id': [analysis_key, dataset_key].join(' / ')] + parameters]}]}

		// collect hashes into a collection of maps
		.collect{k,v -> v.values()}
		.flatten()

		// add default analysis and dataset names
		// - use key if not provided
		// - may be superfluous
		.collect{it + ['analysis name': it.get('analysis name', it.get('analysis key'))]}
		.collect{it + ['dataset name': it.get('dataset name', it.get('dataset key'))]}

		// add default analysis and dataset id
		// - if missing, these are directory-safe versions of the names
		.collect{it + ['analysis id': make_string_directory_safe(it.get('analysis id', it.get('analysis name')))]}
		.collect{it + ['dataset id': make_string_directory_safe(it.get('dataset id', it.get('dataset name')))]}

		// add default values to each set of dataset parameters
		.collect{default_dataset_params.get(it.get('analysis key')) + it}

		// convert strings to file paths for expected keys
		// - makes a relative path absolute
		.collect{convert_map_keys_to_files(it, possible_file_keys)}

		// add in the genome parameters for each dataset
		.collect{it + ['genome parameters': genomes_params.get(it.get('genome'))]}

		// reformat the stages collection to lower-case, non-space
		.collect{it + [stages: it.get('stages').collect{it.toLowerCase().replaceAll(' ', '_').replaceAll('/', ':')}]}

		// if `quantification method` is provided, make it safe
		.collect{it + (it.keySet().contains('quantification method') ? ['quantification method': it.get('quantification method').replaceAll(' ', '_')] : [:])}

		// filter for datasets that contain a specific processing stage
		.findAll{it.get('stages', []).contains(stage) | stage==null}
}

// create a list of genomes used in this project
// -- returns a list of maps, one for each genome
// ++ find a genome: genomes.find{it.'key'=='mouse'}
// ++ add an element to a specific genome: genomes.find{it.'key'=='mouse'}.put('foo','bar')

def get_genomes_params() {
	pluck(params, ['_project', 'genomes'])
		// .collectEntries{key, parameters -> [key, parameters + ['genome': key, 'unique id': key]]}
		.collectEntries{key, parameters -> [key, parameters + ['key': key]]}
		.collectEntries{key, parameters -> [key, parameters + ['id': make_string_directory_safe(parameters.get('id', parameters.get('key')))]]}
		.collectEntries{key, parameters -> [key, parameters + ['unique id': parameters.get('unique id', parameters.get('key'))]]}
}

// get a hash of default parameters to use in dataset stanzas
// - default parameters stanzas are called '_defaults'

def get_default_dataset_params() {
	def default_analysis_params = params.get('_defaults', [:])
	get_analysis_params()
		.collectEntries{analysis_key, datasets -> [analysis_key, default_analysis_params + datasets.get('_defaults', [:])]}
}

// get a hash of analysis parameters
// - analysis parameter stanzas do  not start with underscore

def get_analysis_params() {
	params.findAll{!it.key.startsWith('_')}
}

// define which parameter keys should be files

def get_possible_file_keys() {
	['index path',
	 'quantification path',
	 'fastq paths',
	 'fasta files',
	 'gtf files',
	 'motifs',
	 'mitochondrial features',
	 'cell cycle genes']
}
