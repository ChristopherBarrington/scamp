// collapse strings into a unique key

def format_unique_key(LinkedHashMap values, String sep=' / ') {
  format_unique_key(values.values(), sep)
}

def format_unique_key(Collection values, String sep=' / ') {
  values.join(sep)
}
