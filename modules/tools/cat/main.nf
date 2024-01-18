process cat {
	tag "$output_file"

	cpus 1
	memory '4GB'
	time '1h'

	input:
		val opt
		path 'input_?'
		val regex
		val output_file
		val ignore_stub_run

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path output_file, emit: path

	script:
		catter = 'main.sh'
		catter = output_file ==~ /.*.yaml/ ? 'yaml.sh' : catter
		template workflow.stubRun && ignore_stub_run!='true' ? 'stub.sh' : catter
}
