process count {
	cpus 16
	memory '64GB'
	time '3d'

	input:
		val opt
		val output_dir
		val dataset_ids
		path 'config.csv'

	output:
		val opt, emit: opt
		path 'task.yaml', emit: task
		path "$output_dir/outs/config.csv", emit: config_csv
		path "$output_dir/outs/multi", emit: multi_quantification_path
		path "$output_dir/outs/per_sample_outs/*/count", emit: per_sample_quantification_path
		path "$output_dir/outs/per_sample_outs/*/vdj_b", emit: per_sample_vdjb_path, optional: true
		path "$output_dir/outs/per_sample_outs/*/vdj_t", emit: per_sample_vdjt_path, optional: true
		path "$output_dir/outs/per_sample_summaries/*/metrics_summary.csv", emit: per_sample_metrics_summary
		path "$output_dir/outs/per_sample_summaries/*/web_summary.html", emit: per_sample_web_summary

	script:
		multi_args = task.ext.multi ?: ''
		single_sample_out = dataset_ids.join('-')
		expected_datasets = dataset_ids.multiply(2).join(',')

		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}
