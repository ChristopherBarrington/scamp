process mkref {
	tag "$tag"

	cpus 8
	memory '64GB'
	time '12h'

	input:
		val metadata
		val tag
		val organism
		val assembly
		val non_nuclear_contigs
		path motifs
		path path_to_fastas
		path path_to_gtfs

	output:
		val metadata, emit: metadata
		path 'task.yaml', emit: task
		path 'versions.yaml', emit: versions
		path assembly, emit: path

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}

// https://support.10xgenomics.com/single-cell-multiome-atac-gex/software/pipelines/latest/advanced/references
