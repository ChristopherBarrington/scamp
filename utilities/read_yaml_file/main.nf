// read and return an unaltered yaml file

def read_yaml_file(filename) {
	try {
		@Grab('org.apache.groovy:groovy-yaml')
		def yamlslurper = new groovy.yaml.YamlSlurper()
		yamlslurper.parse(file(filename))
	} catch(Exception e) {
		System.exit(0)
	}
}
