// collapse strings into a unique key

def format_unique_key(values) {
  if(values instanceof java.util.LinkedHashMap)
    values = values.values()
  format_unique_key(values, ' / ')
}

def format_unique_key(values, sep) {
  if(values instanceof java.util.LinkedHashMap)
    values = values.values()
  values.join(sep)
}
