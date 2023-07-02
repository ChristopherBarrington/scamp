// remove keys from a map

def remove_keys_from_map(x, String key) {
	remove_keys_from_map(x, [key])
}

def remove_keys_from_map(x, Collection keys) {
	def keys_to_keep = x.keySet().findAll{!keys.contains(it)}
	x.subMap(keys_to_keep)
}
