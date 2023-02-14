process make_chromatin_assay {
	tag "$tag"

	// define resource
	cpus 1
	memory '16GB'
	time '1h'

	// define expected input channels
	input:
		val metadata
		val tag
		path 'annotations.rds'
		path 'counts_matrices.rds'
		path 'quantification_path'
		val feature_type

	// define expected output channels
	output:
		val metadata, emit: metadata
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'assay.rds', emit: assay

	// define any additional nextflow properties to pass to the template script
	script:
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
