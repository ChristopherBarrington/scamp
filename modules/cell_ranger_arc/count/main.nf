process count {
	tag "$tag"

	cpus 16
	memory '64GB'
	time '3d'

	input:
		val opt
		val tag
		val id
		val description
		val samples
		path 'index_path'
		file 'all_libraries.csv'

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path 'libraries.csv', emit: libraries
		path "$id/outs", emit: quantification_path
		path 'atac_summary.html', emit: atac_summary
		path 'joint_summary.html', emit: joint_summary
		path 'rna_summary.html', emit: rna_summary

	script:
		count_args = task.ext.count ?: ''
		samples_regex = samples.join('|')
		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}
