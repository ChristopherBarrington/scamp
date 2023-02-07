
def print_pipeline_title(filename='pipeline.txt') {
  file([projectDir, 'assets', filename].join('/')).eachLine{println(it)}
}
