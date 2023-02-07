// return a modified string that can be used as a directory name

def make_string_directory_safe(String string) {
  string.replaceAll("[^a-zA-Z0-9-_\\.]", "_");
}
