// (recursively) pluck values from a map

def pluck(map, path, missing='missing') {
  def key = path.get(0)
  def submap = map.get(key, missing)

  // if there are elements in the path
  if(path.size() > 1) {
    // pluck the next element from the map
    return pluck(submap, path.tail(), missing)
  } else {
    // return the plucked element or the missing value
    return submap
  }
}
