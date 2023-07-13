process cat {
	tag "$output_file"

	cpus 1
	memory '4GB'
	time '1h'

	input:
		val opt
		path 'input_?'
		val output_file

	output:
		val opt, emit: opt
		path output_file, emit: path

	script:
		catter = 'main.sh'
		catter = output_file ==~ /.*.yaml/ ? 'yaml.sh' : catter
		template workflow.stubRun ? 'stub.sh' : catter
}
