#! bash

# run cell ranger multi
cellranger multi ${multi_args} \\
	--id=${output_dir} \\
	--description="Cell Ranger (multi) analysis of ${output_dir}" \\
	--csv=config.csv \\
	--jobmode=local --localcores=${task.cpus} --localmem=${task.memory.toGiga()} \\
	--disable-ui

# if the library contains only one sample, rename the per_sample_outs from id to single_sample_out
if [[ `find ${output_dir}/outs/per_sample_outs -mindepth 1 -maxdepth 1 -type d -printf '%P'` == ${output_dir} ]]; then
        mv ${output_dir}/outs/per_sample_outs/{${output_dir},${single_sample_out}}
fi

# move summary reports
# mkdir --parents ${output_dir}/outs/per_sample_summaries \\
# && ls ${output_dir}/outs/per_sample_outs \\
# | xargs --max-args 1 -I @ sh -c "mkdir ${output_dir}/outs/per_sample_summaries/@ && mv ${output_dir}/outs/per_sample_outs/@/{metrics_summary.csv,web_summary.html} ${output_dir}/outs/per_sample_summaries/@/"

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
  task:
    '${task.index}':
      params:
        id: ${output_dir}
        csv: `realpath config.csv`
      meta:
        workDir: `pwd`
  process:
    ext:
      multi: ${multi_args}
    versions:
      cell ranger: `echo "cellranger cellranger-7.1.0" | sed 's/cellranger cellranger-//'`
END_TASK
      # cell ranger: `cellranger --version | sed 's/cellranger cellranger-//'`
