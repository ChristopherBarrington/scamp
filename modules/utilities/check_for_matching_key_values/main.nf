// get values for a list of maps and check they all match

def check_for_matching_key_values(x, key) {
  def values = x.collect{it.get(key)}.minus(null).collect{it.toString()}
  // println(values)
  values.size()>1 && values.every{it==values.first()}
}
