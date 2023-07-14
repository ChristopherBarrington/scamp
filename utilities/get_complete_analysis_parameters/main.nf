// get a complete set of parameters for every parameter set, filling in genomes, shared and default parameters

include { convert_map_keys_to_files }  from '../convert_map_keys_to_files'
include { make_string_directory_safe } from '../make_string_directory_safe'
include { pluck }                      from '../pluck'
include { remove_keys_from_map }       from '../remove_keys_from_map'

def get_complete_analysis_parameters(stage=null) {
	def genome_params = get_genome_params()
	def default_dataset_params = get_default_dataset_params()
	def possible_file_keys = get_possible_file_keys()
	def project_parameters = get_project_parameters()

	get_dataset_params()

		// add key information to the parameters stanza
		.collectEntries{dataset_key, parameters -> [dataset_key, ['dataset key': dataset_key] + parameters]}

		// collect hashes into a collection of maps
		.collect{k,v -> v}

		// add default values where parameters are omitted
		.collect{it + ['dataset name': it.get('dataset name', it.get('dataset key'))]}                          // dataset names
		.collect{it + ['dataset id': make_string_directory_safe(it.get('dataset id', it.get('dataset name')))]} // dataset ids
		.collect{it + ['dataset tag': it.get('dataset tag', it.get('dataset id'))]}                             // dataset tags
		.collect{it + ['description': it.get('description', it.get('dataset name'))]}                           // dataset descriptions
		.collect{it + ['feature identifiers': it.get('feature identifiers', 'name')]}                           // feature identifiers

		// add default values to each set of dataset parameters
		.collect{default_dataset_params + it}

		// add genome parameters to each dataset
		.collect{it + ['genome parameters': genome_params]}

		// try to make parameters safe by regex
		.collect{it + [stages: it.get('stages').collect{it.toLowerCase().replaceAll(' ', '_').replaceAll('/', ':')}]}                                          // reformat the stages collection to lower-case, non-space
		.collect{it + (it.keySet().contains('quantification method') ? ['quantification method': it.get('quantification method').replaceAll(' ', '_')] : [:])} // if `quantification method` is provided, make it safe

		// convert strings to absolute file paths for expected keys
		.collect{convert_map_keys_to_files(it, possible_file_keys)}

		// filter for datasets that contain a specific processing stage
		.findAll{it.get('stages', []).contains(stage) | stage==null}
}

// get a hash of genome parameters

def get_genome_params() {
	def genome_params = get_scamp_params().get('_genome')
	genome_params
		.plus(['name': genome_params.get('name', 'genome')])
		.plus(['id': make_string_directory_safe(genome_params.get('id', genome_params.get('name')))])
}

// get a hash of default parameters to use in all datasets

def get_default_dataset_params() {
	get_scamp_params().get('_defaults')
}

// get a hash of dataset parameters

def get_dataset_params() {
	get_scamp_params().get('_datasets')
}

// get a hash of _project parameters

def get_project_parameters() {
	[type: '10X-3prime'] + get_scamp_params().get('_project')
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
	 'fasta file', 'fasta path',
	 'gtf file', 'gtf path',
	 'motifs file',
	 'mitochondrial features',
	 'cell cycle genes']
}
