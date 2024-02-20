// find the key that has a given value in a map

def find_key_of_value(map, value) {
	map.find{test_value(it.value, value)}?.key
}

// test if a string matches a value
def test_value(String x, String value) {
	x == value
}

// test if an array contains a value
def test_value(java.util.ArrayList x, String value) {
	x.contains(value)
}
