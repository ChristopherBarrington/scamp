process count {
	tag "$tag"

	cpus 8
	memory '64GB'
	time '3d'

	input:
		val opt
		val tag
		val id
		val samples
		path 'index_path'
		file 'all_libraries.csv'

	output:
		val opt, emit: opt
    path 'task.yaml', emit: task
    path 'versions.yaml', emit: versions
		path 'libraries.csv', emit: libraries
    path "$id/SC_ATAC_GEX_COUNTER_CS/SC_ATAC_GEX_COUNTER/_SC_ATAC_REPORTER/CREATE_WEBSUMMARY/*/*/files/web_summary.html", emit: atac_summary
    path "$id/SC_ATAC_GEX_COUNTER_CS/SC_ATAC_GEX_COUNTER/GEX_SUMMARIZE_REPORTS/*/*/files/web_summary.html", emit: rna_summary
    path "$id/outs/web_summary.html", emit: joint_summary
    path "$id/outs", emit: quantification_path

	script:
		samples_regex = samples.join('|')
		template workflow.stubRun ? 'stub.sh' : 'main.sh'
}
