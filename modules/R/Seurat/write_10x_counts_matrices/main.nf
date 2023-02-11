process write_10x_counts_matrices {
	tag "$tag"

	cpus 1
	memory '8GB'
	time '1h'

	input:
		val uid
		val tag
		path 'barcoded_matrix'
		val feature_identifier

	output:
		val uid, emit: uid
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'counts_matrices.rds', emit: counts_matrices
		path 'features.rds', emit: features

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
