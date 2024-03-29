process convert_gtf_to_granges {
	tag "$genome"

	cpus 1
	memory '8GB'
	time '1h'

	input:
		val opt
		val genome
		path gtf
		path fai

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path 'granges.rds', emit: granges

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
