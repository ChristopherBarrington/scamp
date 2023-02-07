// convert a set of keys (strings) into files

def convert_map_keys_to_files(x, keys) {
	if(x instanceof java.util.LinkedHashMap)
		x.collectEntries{key, value -> [key, keys.contains(key) ? convert_to_files(value) : convert_map_keys_to_files(value, keys)]}
	else
		x
}

def convert_to_files(x) {
	if(x instanceof java.util.LinkedHashMap) x.collectEntries{k,v -> [k, file(v)]}
	else if(x instanceof java.util.ArrayList) x.collect{file(it)}
	else if(x instanceof String) file(x)
	else x
}
