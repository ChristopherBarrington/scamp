// convert a set of keys (strings) into files

def convert_to_files(x) {
	x
}

def convert_to_files(String x) {
	file(x)
}

def convert_to_files(java.util.ArrayList x) {
	x.collect{file(it)}
}

def convert_to_files(java.util.LinkedHashMap x) {
	x.collectEntries{k,v -> [k, file(v)]}
}

def convert_map_keys_to_files(x, keys) {
	x
}

def convert_map_keys_to_files(java.util.LinkedHashMap x, keys) {
	x.collectEntries{key, value -> [key, keys.contains(key) ? convert_to_files(value) : convert_map_keys_to_files(value, keys)]}
}
