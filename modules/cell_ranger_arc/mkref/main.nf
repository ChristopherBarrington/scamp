process mkref {
	tag "$tag"

	cpus 8
	memory '64GB'
	time '12h'

	input:
		val uid
		val tag
		val organism
		val assembly
		val non_nuclear_contigs
		path motifs
		path path_to_fastas
		path path_to_gtfs

	output:
		val uid, emit: uid
		path assembly, emit: path
		path 'versions.yaml', emit: versions

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}

// https://support.10xgenomics.com/single-cell-multiome-atac-gex/software/pipelines/latest/advanced/references
