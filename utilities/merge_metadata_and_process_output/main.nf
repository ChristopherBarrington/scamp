// merge a key `metadata` with all other keys in the map

def merge_metadata_and_process_output(x) {
	def keyset = x.keySet()
	x.get(keyset.first()) + x.subMap(keyset.tail())
}
