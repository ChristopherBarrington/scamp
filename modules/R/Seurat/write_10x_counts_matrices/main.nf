process write_10x_counts_matrices {
	tag "$tag"

	// define resource
	cpus 1
	memory '8GB'
	time '1h'

	// define expected input channels
	input:
		val opt
		val tag
		path 'barcoded_matrix'
		val feature_identifier

	// define expected output channels
	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'counts_matrices.rds', emit: counts_matrices
		path 'features.rds', emit: features

	// define any additional nextflow properties to pass to the template script
	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
