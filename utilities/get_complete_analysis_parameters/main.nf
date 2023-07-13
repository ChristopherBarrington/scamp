// get a complete set of parameters for every parameter set, filling in genomes, shared and default parameters

include { convert_map_keys_to_files }  from '../convert_map_keys_to_files'
include { make_string_directory_safe } from '../make_string_directory_safe'
include { pluck }                      from '../pluck'
include { remove_keys_from_map }       from '../remove_keys_from_map'

def get_complete_analysis_parameters(stage=null) {
	def genomes_params = get_genomes_params()
	def default_dataset_params = get_default_dataset_params()
	def possible_file_keys = get_possible_file_keys()
	def project_parameters = get_project_parameters()

	get_dataset_params()
		// remove the default dataset parameters
		// - these are collected above
		// .collectEntries{analysis_key, datasets -> [analysis_key, remove_keys_from_map(datasets, '_defaults')]}

		// add key information to the parameters stanza
		// - copy across: analysis and dataset key
		// - make an unique identifier for the parameter set
		.collectEntries{dataset_key, parameters -> [dataset_key, ['dataset key': dataset_key, 'unique id': dataset_key] + parameters]}

		// collect hashes into a collection of maps
		.collect{k,v -> v}

		// add default values where parameters are omitted
		.collect{it + ['dataset name': it.get('dataset name', it.get('dataset key'))]}                          // dataset names
		.collect{it + ['dataset id': make_string_directory_safe(it.get('dataset id', it.get('dataset name')))]} // dataset ids
		.collect{it + ['dataset tag': it.get('dataset tag', it.get('dataset id'))]}                             // dataset tags
		.collect{it + ['description': it.get('description', it.get('dataset name'))]}                           // dataset descriptions
		.collect{it + ['feature identifiers': it.get('feature identifiers', 'name')]}                           // feature identifiers
		.collect{it + ['genome': it.get('genome', genomes_params.keySet().first())]}                            // genome

		// add default values to each set of dataset parameters
		.collect{default_dataset_params + it}

		// add in the genome parameters for each dataset
		.collect{it + ['genome parameters': genomes_params.get(it.get('genome'))]}

		// try to make parameters safe by regex
		.collect{it + [stages: it.get('stages').collect{it.toLowerCase().replaceAll(' ', '_').replaceAll('/', ':')}]} // reformat the stages collection to lower-case, non-space
		.collect{it + (it.keySet().contains('quantification method') ? ['quantification method': it.get('quantification method').replaceAll(' ', '_')] : [:])} // if `quantification method` is provided, make it safe

		// convert strings to absolute file paths for expected keys
		.collect{convert_map_keys_to_files(it, possible_file_keys)}

		// filter for datasets that contain a specific processing stage
		.findAll{it.get('stages', []).contains(stage) | stage==null}
}

// create a list of genomes used in this project
// -- returns a list of maps, one for each genome
// ++ find a genome: genomes.find{it.'key'=='mouse'}
// ++ add an element to a specific genome: genomes.find{it.'key'=='mouse'}.put('foo','bar')

def get_genomes_params() {
	pluck(get_scamp_params(), ['_project', 'genomes'])
		// .collectEntries{key, parameters -> [key, parameters + ['genome': key, 'unique id': key]]}
		.collectEntries{key, parameters -> [key, parameters + ['key': key]]}
		.collectEntries{key, parameters -> [key, parameters + ['id': make_string_directory_safe(parameters.get('id', parameters.get('key')))]]}
		.collectEntries{key, parameters -> [key, parameters + ['unique id': parameters.get('unique id', parameters.get('key'))]]}
}

// get a hash of default parameters to use in dataset stanzas
// - default parameters stanzas are called '_defaults'

def get_default_dataset_params() {
	get_scamp_params().get('_defaults')
}

// get a hash of dataset parameters

def get_dataset_params() {
	get_scamp_params().get('_datasets')
}

// get a hash of _project parameters

def get_project_parameters() {
	[type: '10X-3prime'] + get_scamp_params().get('_project', [:])
}

// read and parse the scamp parameters

def get_scamp_params() {
	try {
		@Grab('org.apache.groovy:groovy-yaml')
		def yamlslurper = new groovy.yaml.YamlSlurper()
		yamlslurper.parse(file(params.get('scamp_file')))
	} catch(Exception e) {
		System.exit(0)
	}
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
