// collapse strings into a unique key

def format_unique_key(values) {
  if(values instanceof java.util.LinkedHashMap)
    values = values.values()
  values.join(' / ')
}
