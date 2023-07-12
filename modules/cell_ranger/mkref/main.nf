process mkref {
	tag "$tag"

	cpus 16
	memory '64GB'
	time '12h'

	input:
		val opt
		val tag
		val assembly
		path 'fasta'
		path 'gtf'

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path assembly, emit: path

	script:
		mkref_args = task.ext.mkref ?: ''
		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}

// https://support.10xgenomics.com/single-cell-gene-expression/software/pipelines/latest/advanced/references
