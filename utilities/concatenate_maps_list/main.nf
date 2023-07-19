// sequentially add maps in a list together

def concatenate_maps_list(x) {
	if(x.every{it instanceof java.util.ArrayList})
		println('[concatenate_maps_list] given a list of ArrayLists! maybe use flatten?')

	x.inject([:]) {a,b -> a+b}
}

// TODO: add check for matching key pairs but different values
