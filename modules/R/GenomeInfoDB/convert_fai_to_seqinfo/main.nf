process convert_fai_to_seqinfo {
	tag "$tag"

	cpus 1
	memory '4GB'
	time '1h'

	input:
		val opt
		val tag
		val genome_name
		path fai_file

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path 'seqinfo.rds', emit: seqinfo

	script:
		template workflow.stubRun ? 'main.Rscript' : 'main.Rscript'
}
