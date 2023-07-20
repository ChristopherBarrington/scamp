// check and fill scamp parameters

import java.nio.file.Paths

include { concatenate_maps_list }      from '../concatenate_maps_list'
include { make_string_directory_safe } from '../make_string_directory_safe'
include { parse_scamp_parameters }     from '../parse_scamp_parameters'
include { read_yaml_file }             from '../read_yaml_file'

include { print_as_json } from '../print_as_json'

// validate provided project parameters against the pipeline's schema for _genome and _dataset stanzas

def validate_scamp_parameters() {
	// split the parameter sets into scopes to match the schema
	def project_parameters = parse_scamp_parameters()
		.collect{[(it.get('dataset key')): [_genome: it.get('genome parameters'), _dataset: it.findAll{it.key != 'genome parameters'}]]}
		.inject([:]){a,b -> a+b}

	// read the parameter schema from file
	def parameter_specifications = read_yaml_file(Paths.get(workflow.projectDir.toString(), 'main.yaml'))
		.collect{it.findAll{it.key != 'parameters'} + ['parameters': it.get('parameters').collect{[(it.get('name')): it.findAll{it.key != 'name'}]}]}
		.collect{[(it.get('name')): concatenate_maps_list(it.get('parameters'))]}
		.inject([:]) {x,y -> x+y}

	// keep the messages for each dataset in the `output_messages` map
	def output_messages = [:]

	// loop through datasets, stanzas and parameter names
	for(dataset in project_parameters.keySet()) {
		output_messages += [(dataset): []] // add a line to show the current dataset
		def msg = '[ ------- ] undefined message'
		def dataset_parameters = project_parameters.get(dataset)

		// for this dataset, get the analysis stages and then get the expected parameters for those stages
		def stage_validation = validate_parameter_type(dataset_parameters['_dataset']['stages'], parameter_specifications['_dataset']['stages'])
		if(stage_validation.get('validation').get('outcome') != 'pass') {
			output_messages[dataset] += [warning_message('stages', stage_validation)]
			continue // if there are `stages` then move on to the next dataset
		}

		// for each stage in this dataset's analysis, load the documentation and pluck out the expected parameters stanza
		// merge the _dataset and _genome stanzas into a unique set of required parameters for this dataset
		// `dataset name` and `dataset id` are used for other defaults, so add them here even if they're not used in the workflow
		def dataset_stages = project_parameters
			.get(dataset).get('_dataset').get('stages')
		def required_parameters = dataset_stages
			*.replaceAll(':', '/')
			.collect{read_yaml_file(Paths.get('workflows', it, 'readme.yaml')).get('parameters')}
			.inject([_genome: [], _dataset: ['dataset name', 'dataset id']]) {
				a,b -> [_genome: a.get('_genome',[]) + b.get('_genome', []),
				        _dataset: a.get('_dataset',[]) + b.get('_dataset',[])]}
			.each{k,v -> v.unique()}

		// for each stanza group, check the required parameters
		for(stanza in project_parameters.get(dataset).keySet()) {
			def stanza_parameters = dataset_parameters.get(stanza)
			def stanza_specifications = parameter_specifications.get(stanza)

			// check each expected parameter against the parameter specification schema
			for(parameter_name in required_parameters.get(stanza)) {
				def parameter = stanza_parameters.get(parameter_name)
				def specification = stanza_specifications.get(parameter_name)
				def result = validate_parameter_type(parameter, specification)

				// interpret the result of validation and adding the messages to `output_messages` and updating the default value for the parameter if possible and it was missing
				def result_interpretation = interpret_validatation_result(parameter_name, result, dataset_stages, dataset_parameters, stanza_parameters, parameter_specifications)
				output_messages[dataset] += result_interpretation.get('messages')
				if(result_interpretation.get('default_value'))
					project_parameters[dataset][stanza][parameter_name] = result_interpretation.get('default_value')
			}
		}
	}

	// print all output messages if the user opted to or they only wanted to validate the parameters
	if(params.show_parameter_validation || params.only_validate_parameters) {
		def full_output_message = output_messages
			.collect{k,v -> ([title_message(k)] + v.sort()).join('\n')}
			.join('\n')

		println(full_output_message)
		println()
	}

	// pull out the fail and default messages, ready to print
	def fail_output_messages = output_messages
		.collectEntries{k,v -> [(k): v.findAll{it.matches('. FAIL +. .*')}]}
		.findAll{it.value.size() > 0}

	// if any parameters failed to be validated, print them out (if they have not already) and exit early	
	if(fail_output_messages.size() > 0 ) {
		def fail_output_message = fail_output_messages
			.collect{k,v -> ([title_message(k)] + v).join('\n')}
			.join('\n')

		if(!params.only_validate_parameters)
			println(fail_output_message)

		println('\n!!! some parameters could not be validated. these should be checked, updated and the pipeline restarted. !!!\n')
		System.exit(0)
	}
	
	// end here if the scamp is not meant to start
	if(params.only_validate_parameters)
		System.exit(0)

	// convert and return the scoped parameters back as scamp would expect
	project_parameters
		.collect{k,v -> v.get('_dataset') + ['genome parameters': v.get('_genome')]}
}

// functions to format output messages

def title_message(dataset) {
	def width = 180
	'\n' + dataset + ':'
}

def pass_message(parameter_name) {
	['[ PASS    ] ', parameter_name].join('')
}

def warning_message(parameter_name, r) {
	['[ WARN    ] ', parameter_name, ': ', r.get('validation').get('reason')].join('')
}

def process_provider_message(parameter_name) {
	['[ WARN    ] ', parameter_name, ': ', 'missing, but may be provided by another stage'].join('')
}

def process_provider_message(parameter_name, r) {
	['[ WARN    ] ', parameter_name, ': ', r.get('validation').get('reason')].join('')
}

def fail_message(parameter_name, r) {
	['[ FAIL   *] ', parameter_name, ': ', r.get('validation').get('reason')].join('')
}

def fail_required_parameter_not_specced(parameter_name) {
	['[ ERROR  *] ', parameter_name, ': ', 'not defined in parameter specification schema'].join('')
}

def using_default_message(parameter_name, value) {
	['[ DEFAULT ] ', parameter_name, ': ', 'using default value of `' + value + '`'].join('')
}

// interpret the result of parameter validation and implement parameter- and stage-specific checks
// returns a map with the messages to add and (optionally) the default value to add back into `project_parameters`

def interpret_validatation_result(parameter_name, result, dataset_stages, dataset_parameters, stanza_parameters, parameter_specifications) {
	def messages = []
	if(result == null) {
		messages = fail_required_parameter_not_specced(parameter_name)
	}
	else if(result.get('validation').get('outcome') == 'pass') { // if the parameter passed validation, we don't need to worry
		messages = pass_message(parameter_name)
	}
	else if((parameter_name == 'index path')) { // these are special cases; a process could provide these if provided the right parameters
		if('quantification:cell_ranger' in dataset_stages) // index path was not provided, but is expected. check for fasta/gtf file/path
			messages = check_for_cell_ranger_index_path(parameter_name, result, dataset_parameters, parameter_specifications)

		if('quantification:cell_ranger_arc' in dataset_stages) // index path was not provided, but is expected. check for fasta/gtf file/path, organism, motifs file and non-nuclear contigs
			messages = check_for_cell_ranger_arc_index_path(parameter_name, result, dataset_parameters, parameter_specifications)
	}
	else if(parameter_name == 'fasta index path') {
		// fasta index path was not provided, but can be written using `fasta file`
		messages = process_provider_message(parameter_name, [validation: [reason: result.get('validation').get('reason') + ' checking for fasta files, from which the fasta index could be built.']])
	}
	else if(parameter_name == 'quantification path') {
		if(dataset_parameters.get('_dataset').get('stages').any{it ==~ 'quantification:.*'}) messages = process_provider_message(parameter_name)
		else messages = fail_message(parameter_name, result)
	}
	else if(parameter_name == 'quantification method') {
		if(dataset_parameters.get('_dataset').get('stages').any{it ==~ 'quantification:.*'}) messages = process_provider_message(parameter_name)
		else messages = fail_message(parameter_name, result)
	}
	else { // these parameters should be provided by the user/defaults provided but did not pass validation
		def default_parameter_closure = get_default_parameters().get(parameter_name)
		if(default_parameter_closure) {
			default_value = default_parameter_closure.call(stanza_parameters)
			messages = using_default_message(parameter_name, default_value)
			return([messages: messages, default_value: default_value])
		}
		else {
			messages = fail_message(parameter_name, result)
		}
	}
	return([messages: messages])
}

// make sure that a parameter's expected type is what was provided

def validate_parameter_type(parameter, specification) {
	def outcomes = [pass: [outcome: 'pass'],
	                fail_type: [outcome: 'fail', reason: 'unexpected parameter type!'],
	                unexpected_reference: [outcome: 'fail', reason: 'undefined in schema!'],
	                missing_parameter: [outcome: 'fail', reason: 'not provided in configuration parameters!']]
		.collectEntries{k,v -> [(k):[validation: v, specification: specification]]}

	if(specification == null) {return(outcomes.get('unexpected_reference'))} // not in expected parameter set
	if(parameter == null) {return(outcomes.get('missing_parameter'))} // no parameter from parameters file
	def reference_parameter_type = specification.get('type')
	def type_validator = get_type_validatators().get(reference_parameter_type)
	return(type_validator(parameter) ? outcomes.get('pass') : outcomes.get('fail_type')) // pass or fail type check
}

// define a map of parameter types and functions to test them

def get_type_validatators() {
	['file'  : {it instanceof java.nio.file.Path},
	 'path'  : {it instanceof java.nio.file.Path},
	 'map'   : {it instanceof java.util.Map},
	 'string': {it instanceof java.lang.String},

	 'dictionary' : {it instanceof java.util.Map},

	 'files'  : {it.every{it instanceof java.nio.file.Path}},
	 'paths'  : {it.every{it instanceof java.nio.file.Path}},
	 'strings': {(it.every{it instanceof java.lang.String}) && (it.size() > 0)},

	 'map of strings': {(it instanceof java.util.Map) && (it.every{k,v -> v.every{it instanceof String}})},
	 'string(s)': {((it instanceof java.lang.String) || (it.every{it instanceof java.lang.String})) && (it.size() > 0)}]
}

// define a map that will provide default values, given the map of current values

def get_default_parameters() {
	['dataset name'       : {it -> it.get('dataset key')},
	 'dataset id'         : {it -> make_string_directory_safe(it.get('dataset name'))},
	 'dataset tag'        : {it -> it.get('dataset id')} ,
	 'description'        : {it -> it.get('dataset name')},
	 'feature identifiers': {'name'}]
}

// define some checker functions for often used or process-provided parameters

// check for `fasta path`
def check_for_fasta_path(dataset_parameters, parameter_specifications) {
	parameter_name = 'fasta path'
	result = validate_parameter_type(dataset_parameters['_genome'][parameter_name], parameter_specifications['_genome'][parameter_name])
	if(result.get('validation').get('outcome') == 'pass') {
		// there are fasta files to use
		return(pass_message(parameter_name))
	}
	else {
		// fasta path was not provided
		return(fail_message(parameter_name, result))
	}
}

// check for `fasta file`, if missing look for `fasta path`
def check_for_fasta_file(dataset_parameters, parameter_specifications) {
	parameter_name = 'fasta file'
	result = validate_parameter_type(dataset_parameters['_genome'][parameter_name], parameter_specifications['_genome'][parameter_name])
	if(result.get('validation').get('outcome') == 'pass') {
		// there is a fasta file to use
		return(pass_message(parameter_name))
	}
	else {
		// fasta file was not provided. check for fasta file
		return([process_provider_message(parameter_name, [validation: [reason: result.get('validation').get('reason') + ' checking for fasta path from which a fasta file could be concatenated.']]),
		        check_for_fasta_path(dataset_parameters, parameter_specifications)])
	}
}

// check for `gtf path`
def check_for_gtf_path(dataset_parameters, parameter_specifications) {
	parameter_name = 'gtf path'
	result = validate_parameter_type(dataset_parameters['_genome'][parameter_name], parameter_specifications['_genome'][parameter_name])
	if(result.get('validation').get('outcome') == 'pass') {
		// there are gtf files to use
		return(pass_message(parameter_name))
	}
	else {
		// gtf path was not provided
		return(fail_message(parameter_name, result))
	}
}

// check for `gtf file`, if missing look for `gtf path`
def check_for_gtf_file(dataset_parameters, parameter_specifications) {
	parameter_name = 'gtf file'
	result = validate_parameter_type(dataset_parameters['_genome'][parameter_name], parameter_specifications['_genome'][parameter_name])
	if(result.get('validation').get('outcome') == 'pass') {
		// there is a gtf file to use
		return(pass_message(parameter_name))
	}
	else {
		// gtf file was not provided. check for gtf file
		return([process_provider_message(parameter_name, [validation: [reason: result.get('validation').get('reason') + ' checking for gtf path from which a gtf file could be concatenated.']]),
		        check_for_gtf_path(dataset_parameters, parameter_specifications)])
	}
}

// check for `index path`, if missing check for `fasta file` and `gtf file`
def check_for_cell_ranger_index_path(parameter_name, result, dataset_parameters, parameter_specifications) {
	[process_provider_message(parameter_name, [validation: [reason: result.get('validation').get('reason') + ' checking for required files, from which a cell ranger index could be built.']])] +
	check_for_fasta_file(dataset_parameters, parameter_specifications) +
	check_for_gtf_file(dataset_parameters, parameter_specifications)
}

// check for `index path`, if missing check for `fasta file`, `gtf file`, `motifs file`, `organism` and `non-nuclear contigs`
def get_result_interpretation_message(parameter_name, dataset_parameters, parameter_specifications) {
	def result = validate_parameter_type(dataset_parameters['_genome'][parameter_name], parameter_specifications['_genome'][parameter_name])
	interpret_validatation_result(parameter_name, result, null, dataset_parameters, null, parameter_specifications)
}

def check_for_cell_ranger_arc_index_path(parameter_name, result, dataset_parameters, parameter_specifications) {
	def motifs_file_result = get_result_interpretation_message('motifs file', dataset_parameters, parameter_specifications)
	def organism_result = get_result_interpretation_message('organism', dataset_parameters, parameter_specifications)
	def non_nuclear_contigs_result = get_result_interpretation_message('non-nuclear contigs', dataset_parameters, parameter_specifications)

	[process_provider_message(parameter_name, [validation: [reason: result.get('validation').get('reason') + ' checking for required files, from which a cell ranger arc index could be built.']])] +
	check_for_fasta_file(dataset_parameters, parameter_specifications) +
	check_for_gtf_file(dataset_parameters, parameter_specifications) +
	[motifs_file_result, organism_result, non_nuclear_contigs_result].collect{it.messages}  
}
