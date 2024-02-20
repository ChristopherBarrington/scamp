// read the parameters file and add already-defined shared parameters

include { convert_map_keys_to_files }  from '../convert_map_keys_to_files'
include { make_string_directory_safe } from '../make_string_directory_safe'
include { pluck }                      from '../pluck'
include { read_yaml_file }             from '../read_yaml_file'
include { remove_keys_from_map }       from '../remove_keys_from_map'

def parse_scamp_parameters() {
	def genome_params = get_genome_params()
	def project_params = get_project_params()
	def default_dataset_params = get_default_dataset_params()
	def possible_file_keys = get_possible_file_keys()
	def project_parameters = get_project_parameters()

	get_dataset_params()

		// add key information to the parameters stanza
		.collectEntries{dataset_key, parameters -> [dataset_key, ['dataset key': dataset_key] + parameters]}

		// collect hashes into a collection of maps
		.collect{k,v -> v}

		// add genome and project parameters to each dataset
		.collect{it + ['genome parameters': genome_params, 'project parameters': project_params]}

		// add default values to each set of dataset parameters
		.collect{default_dataset_params + it}

		// add default values where parameters are omitted
		// .collect{it + ['dataset name': it.get('dataset name') ?: it.get('dataset key')]}                          // dataset names
		// .collect{it + ['dataset id': make_string_directory_safe(it.get('dataset id') ?: it.get('dataset name'))]} // dataset ids
		// .collect{it + ['dataset tag': it.get('dataset tag') ?: it.get('dataset id')]}                             // dataset tags
		// .collect{it + ['description': it.get('description') ?: it.get('dataset name')]}                           // dataset descriptions
		// .collect{it + ['feature identifiers': it.get('feature identifiers') ?: 'name']}                           // feature identifiers

		// try to make parameters safe by regex
		.collect{it + [workflows: it.get('workflows').collect{it.toLowerCase().replaceAll(' ', '_').replaceAll('/', ':')}]}                                          // reformat the workflows collection to lower-case, non-space
		.collect{it + (it.keySet().contains('quantification method') ? ['quantification method': it.get('quantification method').replaceAll(' ', '_')] : [:])} // if `quantification method` is provided, make it safe

		// convert strings to absolute file paths for expected keys
		.collect{convert_map_keys_to_files(it, possible_file_keys)}
}

// filter for datasets that contain a specific processing workflow

def parse_scamp_parameters(String workflow) {
		parse_scamp_parameters().findAll{it.get('workflows', []).contains(workflow)}
}

// get a hash of genome parameters

def get_genome_params() {
	def genome_params = get_scamp_params().get('_genome')
	genome_params
		.plus([id: make_string_directory_safe(genome_params.get('id', genome_params.get('assembly')))])
}

// get a hash of project parameters

def get_project_params() {
	def project_params = get_scamp_params().get('_project')

	// define `type`, if missing, and update `types` from `type`; `type` takes priority and will define `types` even if user-specified
	project_params
		.plus([type: project_params.get('type', '10x-3prime').toLowerCase()])
		.plus([types: project_params.get('type').split('-').sort()])
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
	read_yaml_file(params.get('scamp_file'))
}

// parse barcodes into a string, if there are multiple barcodes for the same dataset

def concatenate_barcodes(java.util.LinkedHashMap x) {
	if(x.keySet().contains('barcode'))
		x.barcode = concatenate_barcodes(x.barcode)
	x
}

def concatenate_barcodes(String barcode) {
	barcode
}

def concatenate_barcodes(java.util.ArrayList barcodes) {
	barcodes.join('|')
}

// define which parameter keys should be files

def get_possible_file_keys() {
	['adt set path',
	 'cell cycle genes',
	 'fastq paths',
	 'fasta file',
	 'fasta index file',
	 'fasta path',
	 'gtf file',
	 'gtf path',
	 'hto set path',
	 'index path',
	 'mitochondrial features',
	 'motifs file',
	 'probe set path',
	 'quantification path',
	 'vdj index path']
}
