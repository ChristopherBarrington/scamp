process count {
	tag "$tag"

	cpus 8
	memory '64GB'
	time '3d'

	input:
		val uid
		val tag
		val output_directory
		val samples
		val additional_arguments
		path 'index_path'
		file 'all_libraries.csv'

	output:
		val uid, emit: uid
		path 'index_path', emit: index_path
		path "$output_directory/outs", emit: quantification_path
		path 'libraries.csv', emit: libraries
		path 'versions.yaml', emit: versions

	script:
		samples_regex = samples.join('|')
		"""
		# get software version(s)
		VERSION=`cellranger-arc --version | cut -f2 -d' ' | sed 's/cellranger-arc-//'`

		# write the software versions
		write_yaml.sh ${task.process}:versions "cell ranger arc" "\${VERSION}" > task.yaml

		# write parameters to a (yaml) file
		write_yaml.sh "${task.process}:$tag" \
			uid "$uid" \
			output_directory "$output_directory" \
			samples "$samples" \
			index_path "`realpath index_path`" \
			complete_libraries "`realpath all_libraries.csv`" \
			additional_arguments "$additional_arguments" \
			task_index "${task.index}" >> task.yaml

		# filter the complete libraries file for the samples in this dataset
		awk --assign FS=',' 'NR==1{print} ; \$2~/^($samples_regex)\$/{print}' all_libraries.csv > libraries.csv

		# run cell ranger arc count
		cellranger-arc count \
			$additional_arguments \
			--id=$output_directory \
			--libraries=libraries.csv \
			--reference=index_path \
			--jobmode=local --localcores=${task.cpus} --localmem=${task.memory.toGiga()}

		# write software versions used in this module
		cat <<-END_VERSIONS > versions.yaml
		"${task.process}":
		    cell ranger arc: \${VERSION}
		END_VERSIONS
		"""

	stub:
		samples_regex = samples.join('|')
		"""
		# get software version(s)
		VERSION=`cellranger-arc --version | cut -f2 -d' ' | sed 's/cellranger-arc-//'`

		# filter the complete libraries file for the samples in this dataset
		awk --assign FS=',' 'NR==1{print} ; \$2~/^($samples_regex)\$/{print}' all_libraries.csv > libraries.csv

		# run cell ranger arc count
		# cellranger-arc count ...
		mkdir --parents $output_directory/outs

		# write software versions used in this module
		cat <<-END_VERSIONS > versions.yaml
		"${task.process}":
		    cell ranger arc: \${VERSION}
		END_VERSIONS
		"""
}
