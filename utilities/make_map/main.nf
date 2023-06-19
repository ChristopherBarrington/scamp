// shortcut to make a map given values and keys

def make_map(values, keys) {
  [keys, values]
    .transpose()
    .collectEntries()
}
