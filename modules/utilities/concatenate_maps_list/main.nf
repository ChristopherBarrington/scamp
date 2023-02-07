// sequentially add maps in a list together

def concatenate_maps_list(a) {
  if(a.every{it instanceof java.util.ArrayList})
    println('[concatenate_maps_list] given a list of ArrayLists! maybe use flatten?')

  def b = a.first()
  a.tail()
    .each{b=b+it}

  return b
}
