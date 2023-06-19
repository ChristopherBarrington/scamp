// print a map as a pretty json

import static groovy.json.JsonOutput.*

def print_as_json(inmap) {
	inmap = convert_file_to_string(inmap)

	println('/// ' + '-'*246)
	print(prettyPrint(toJson(inmap)))
	println('/// ' + '-'*246)
}

def convert_file_to_string(x) {
	if(x instanceof java.util.ArrayList) x.collect{convert_file_to_string(it)}
	else if(x instanceof java.util.LinkedHashMap) x.collectEntries{k,v -> [k, convert_file_to_string(v)]}
	else if(x.getClass() == file('/').getClass()) x.toString()
	else x
}
