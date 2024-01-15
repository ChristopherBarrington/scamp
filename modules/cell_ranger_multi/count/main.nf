process multi {
	cpus 16
	memory '64GB'
	time '3d'

	input:
		val opt
		val id
		val dataset_ids
		path 'config.csv'

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path "$id/outs/config.csv", emit: config_csv
		path "$id/outs/multi", emit: multi_quantification_path
		path "$id/outs/per_sample_outs/*", emit: per_sample_quantification_path

	script:
		multi_args = task.ext.multi ?: ''
		expected_datasets = dataset_ids.join(',')

		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}
