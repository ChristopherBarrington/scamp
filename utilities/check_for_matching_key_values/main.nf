// get values for a list of maps and check they all match

def check_for_matching_key_values(x, keys) {
  def values = x.collect{it.subMap(keys)}.collect{it.values()}.flatten().collect{it.toString()}
  values.size()>1 && values.every{it==values.first()}
}
