process make_object {
	tag "$tag"

	cpus 1
	memory '4GB'
	time '1h'

	input:
		val metadata
		val tag
		path 'assays/?.rds'
		val assay_names
		val dataset_tag
		path 'misc/?.rds'
		val misc_names
		val project

	output:
		val metadata, emit: metadata
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path 'seurat.rds', emit: seurat

	script:
		assay_names = assay_names.join(',')
		misc_names = misc_names.join(',')
		template workflow.stubRun ? 'stub.sh' : 'main.Rscript'
}
