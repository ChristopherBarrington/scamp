process convert_fai_to_seqinfo {
	tag "$tag"

	cpus 1
	memory '4GB'
	time '1h'

	input:
		val uid
		val tag

		val genome_name
		path fai_file

	output:
		val uid, emit: uid
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions

		path 'seqinfo.rds', emit: seqinfo

	script:
		output_seqinfo = 'seqinfo.rds'
		template workflow.stubRun ? 'main.Rscript' : 'main.Rscript'
}
