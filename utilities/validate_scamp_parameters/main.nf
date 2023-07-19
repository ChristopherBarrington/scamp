// check and fill scamp parameters

include { concatenate_maps_list }     from '../concatenate_maps_list'
include { make_string_directory_safe } from '../make_string_directory_safe'
include { parse_scamp_parameters }    from '../parse_scamp_parameters'
include { read_yaml_file } from '../read_yaml_file'

include { print_as_json } from '../print_as_json'

// validate provided project parameters against the pipeline schema's _genome and _dataset stanzas

def validate_scamp_parameters(parameters = parse_scamp_parameters(), show_all = false, validate_only = true) {
	// split the parameter sets into scopes to match the schema
	parameters = parameters
		.collect{[(it.get('dataset key')): [_genome: it.get('genome parameters'), _dataset: it.findAll{it.key != 'genome parameters'}]]}
		.inject([:]){a,b -> a+b}

	// read the parameter schema from file
	def reference_parameters = read_yaml_file('main.yaml')
		.collect{it.findAll{it.key != 'parameters'} + ['parameters': it.get('parameters').collect{[(it.get('name')): it.findAll{it.key != 'name'}]}]}
		.collect{[(it.get('name')): concatenate_maps_list(it.get('parameters'))]}
		.inject([:]) {x,y -> x+y}

	// check through each dataset in the project for parameters
	parameter_validation = parameters
		.collectEntries{dataset_name,dataset_parameters -> [(dataset_name): validate_dataset_parameters(dataset_parameters, reference_parameters)]}

	// print out a summary
	def output_messages = [:]
	def default_parameter_closures = get_default_parameters()
	for(dataset in parameter_validation.keySet()) {
		output_messages = output_messages + [(dataset): []]
		
		// for this dataset, get the analysis stages and then get the expected parameters for those stages
		if(parameter_validation.get(dataset).get('_dataset').get('stages').get('validation').get('outcome') != 'pass') {
			def msg = warning_message('stages', parameter_validation.get(dataset).get('_dataset').get('stages'))
			output_messages[dataset] = output_messages[dataset] + [msg]
			continue
		}

		// for each stage in this dataset's analysis, load the documentation and pluck out the expected parameters stanza and make it look like xxxx below
		def stages = parameters
			.get(dataset).get('_dataset').get('stages')
			*.replaceAll(':', '/')
			// .collect{[_genome: ['assembly'], _dataset: ['index path', 'dataset name', 'dataset id']]} //////// this should come from the doc file
			// .inject([:]){a,b -> [_genome: a.get('_genome',[]) + b.get('_genome', []),
	                //      _dataset: a.get('_dataset',[]) + b.get('_dataset',[])]}
			// .each{k,v -> v.unique()}


			print_as_json(stages)

// get parameters required by each stage
def xxxx = [[_genome: ['assembly'],
             _dataset: ['index path', 'dataset name', 'dataset id']],
            [_dataset: ['quantification method', 'quantification path', 'index path', 'feature types']]]

def required_parameters = xxxx
	.inject([:]){a,b -> [_genome: a.get('_genome',[]) + b.get('_genome', []),
	                     _dataset: a.get('_dataset',[]) + b.get('_dataset',[])]}
	.each{k,v -> v.unique()}








		for(stanza in parameter_validation.get(dataset).keySet()) {
			for(parameter_name in required_parameters.get(stanza) + ['stages']) {
				def result = parameter_validation.get(dataset).get(stanza).get(parameter_name)
				def msg = '[ ------- ] undefined message'

				if(result == null) {
					msg = fail_required_parameter_not_specced(parameter_name)
				}
				else if(result.get('validation').get('outcome') == 'pass') { // if the parameter passed validation, we don't need to worry
					msg = pass_message(parameter_name)
				}
				else if(parameter_name == 'index path') { // these are special cases; a process could provide these if provided the right parameters
					// index path was not provided, but is expected. check for fasta/gtf file/path
					process_provider_message(parameter_name, [validation: [reason: result.get('validation').get('reason') + ' checking for fasta and gtf files, from which an index could be built.']])					

					// check for fasta stuff
					parameter_name = 'fasta file'
					result = parameter_validation.get(dataset).get('_genome').get(parameter_name)
					if(result.get('validation').get('outcome') == 'pass') {
						// there is a fasta file to use
						msg = pass_message(parameter_name)
					}
					else {
						// fasta file was not provided. check for fasta file
						process_provider_message(parameter_name, [validation: [reason: result.get('validation').get('reason') + ' checking for fasta path from which a fasta file could be concatenated.']])					

						parameter_name = 'fasta path'
						result = parameter_validation.get(dataset).get('_genome').get(parameter_name)
						if(result.get('validation').get('outcome') == 'pass') {
							// there are fasta files to use
							msg = pass_message(parameter_name)
						}
						else {
							// fasta path was not provided
							msg = fail_message(parameter_name, result)
						}
					}

					// check for gtf stuff
					parameter_name = 'gtf file'
					result = parameter_validation.get(dataset).get('_genome').get(parameter_name)
					if(result.get('validation').get('outcome') == 'pass') {
						// there is a gtf file to use
						msg = pass_message(parameter_name)
					}
					else {
						// gtf file was not provided. check for gtf file
						process_provider_message(parameter_name, [validation: [reason: result.get('validation').get('reason') + ' checking for gtf path from which a gtf file could be concatenated.']])					

						parameter_name = 'gtf path'
						result = parameter_validation.get(dataset).get('_genome').get(parameter_name)
						if(result.get('validation').get('outcome') == 'pass') {
							// there are gtf files to use
							msg = pass_message(parameter_name)
						}
						else {
							// gtf path was not provided
							msg = fail_message(parameter_name, result)
						}
					}
				}
				else if(parameter_name == 'quantification path') {
					if(parameters.get(dataset).get('_dataset').get('stages').any{it ==~ 'quantification:.*'}) { msg = process_provider_message(parameter_name) }
					else { msg = fail_message(parameter_name, result) }
				}
				else if(parameter_name == 'quantification method') {
					if(parameters.get(dataset).get('_dataset').get('stages').any{it ==~ 'quantification:.*'}) { msg = process_provider_message(parameter_name) }
					else { msg = fail_message(parameter_name, result) }
				}
				else { // these parameters should be provided by the user/defaults provided but did not pass validation
					def default_parameter_closure = default_parameter_closures.get(parameter_name)
					if(default_parameter_closure) {
						def default_value = default_parameter_closure.call(parameters.get(dataset).get(stanza))
						msg = using_default_message(parameter_name, default_value)
						parameters[dataset][stanza][parameter_name] = default_value
					}
					else {
						msg = fail_message(parameter_name, result)
					}
				}
				output_messages[dataset] = output_messages[dataset] + [msg]
			}
		}
	}

	// pull out the fail and default messages, ready to print
	def fail_output_messages = output_messages
		.collectEntries{k,v -> [(k): v.findAll{it.matches('. FAIL +. .*')}]}
		.findAll{it.value.size() > 0}

	if(fail_output_messages.size() > 0 ) {
		def fail_output_message = fail_output_messages
			.collect{k,v -> ([title_message(k)] + v).join('\n')}
			.join('\n')

		println('!!! some parameters could not be validated. these should be checked, updated and the pipeline restarted. !!!')
		println(fail_output_message)
		System.exit(0)
	}

	// print all output messages
	if(show_all || validate_only) {
		println('!!!  the parameters have been validated and are shown below. they should be ok to run the pipeline. !!!')
		def full_output_message = output_messages
			.collect{k,v -> ([title_message(k)] + v).join('\n')}
			.join('\n')

		println(full_output_message)
	}

	// convert and return the scoped parameters back as scamp would expect
	if(validate_only)
		System.exit(0)

	parameters
		.collect{k,v -> v.get('_dataset') + ['genome parameters': v.get('_genome')]}
}

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
	['[ FAIL    ] ', parameter_name, ': ', r.get('validation').get('reason')].join('')
}

def fail_required_parameter_not_specced(parameter_name) {
	['[ ERROR   ] ', parameter_name, ': ', 'not defined in parameter specification schema'].join('')
}

def using_default_message(parameter_name, value) {
	['[ DEFAULT ] ', parameter_name, ': ', 'using default value of `' + value + '`'].join('')
}

// validate the parameters for a `dataset` stanza; these are dataset parameters + `_defaults`

def validate_dataset_parameters(parameters, parameter_specs) {
	parameters
		.collectEntries{scope,scope_parameters -> [(scope): validate_scope_parameters(scope_parameters, parameter_specs.get(scope))]}		
}

// validate parameters specified by a list of expected parameters

def validate_scope_parameters(parameters, scope_specs) {
	scope_specs
		.collectEntries{name,spec -> [(name): validate_parameter_type(parameters.get(name), spec) + [parameter: parameters.get(name)]]}
}

// make sure that a parameter's expected type is what was provided

def validate_parameter_type(parameter, spec) {
	def outcomes = [pass: [outcome: 'pass'],
		        fail_type: [outcome: 'fail', reason: 'unexpected parameter type!'],
		        unexpected_reference: [outcome: 'fail', reason: 'undefined in schema!'],
		        missing_parameter: [outcome: 'fail', reason: 'not provided in configuration parameters!']]
		.collectEntries{k,v -> [(k):[validation: v, spec: spec]]}

	if(spec == null) {return(outcomes.get('unexpected_reference'))} // not in expected parameter set
	if(parameter == null) {return(outcomes.get('missing_parameter'))} // no parameter from parameters file
	def reference_parameter_type = spec.get('type')
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
	 'strings': {(it.every{it instanceof java.lang.String}) & (it.size() > 0)},

	 'map of strings': {(it instanceof java.util.Map) & (it.every{k,v -> v.every{it instanceof String}})},
	 'string(s)': {((it instanceof java.lang.String) | (it.every{it instanceof java.lang.String})) & (it.size() > 0)}]
}

// define a map that will provide default values, given the map of current values

def get_default_parameters() {
	['dataset name'       : {it -> it.get('dataset key')},
	 'dataset id'         : {it -> make_string_directory_safe(it.get('dataset name'))},
	 'dataset tag'        : {it -> it.get('dataset id')} ,
	 'description'        : {it -> it.get('dataset name')},
	 'feature identifiers': {'name'}]
}
