process make_assay {
	tag "$tag"

	cpus 1
	memory '16GB'
	time '1h'

	input:
		val uid
		val tag
		val feature_type
		path 'counts_matrices.rds'

	output:
		val uid, emit: uid
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'assay.rds', emit: assay

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
