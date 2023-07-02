// sequentially add maps in a list together

def concatenate_maps_list(x) {
  if(x.every{it instanceof java.util.ArrayList})
    println('[concatenate_maps_list] given a list of ArrayLists! maybe use flatten?')

  def y = x.first()
  x.tail()
    .each{y=y+it}

  return y
}

// TODO: add check for matching key pairs but different values
