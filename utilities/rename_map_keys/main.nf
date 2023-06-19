// rename a set of map keys

def rename_map_keys(map, from, to) {
  from = from.class==String ? [from] : from
  to = to.class==String ? [to] : to
  [from, to]
    .transpose().each{
      map.put(it[1], map.get(it[0]))
      map.remove(it[0])}
  return map
}
