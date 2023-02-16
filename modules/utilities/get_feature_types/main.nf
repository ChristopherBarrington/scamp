// get feature types from params
// returns a list of sample name and feature type tuples

include { pluck } from '../pluck'

def get_feature_types() {
	def feature_types = pluck(params, ['project', 'feature types'])
	['sample_names':feature_types.collect{it.getValue()}.flatten(),
 	 'feature_types':feature_types.keySet().collect{[it]*feature_types.get(it).size()}.flatten()]
}
