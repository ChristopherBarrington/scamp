process faidx {
	tag "$fasta"

	cpus 1
	memory '4GB'
	time '1h'

	input:
		val opt
		path fasta

	output:
		val opt, emit: opt
		path 'versions.yaml', emit: versions
		path '*.fai', emit: path

	script:
		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}
