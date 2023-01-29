process read_matrix {
	tag "$tag"

	conda '/camp/stp/babs/working/barrinc/conda/envs/r-4.1.1'

	cpus 4
	memory '16GB'
	time '1h'

	input:
		val uid
		val tag
		path 'inputs'
		path 'index'

	output:
		val uid
		path 'seurat.rds'

	script:
		template 'main.Rscript'
}
