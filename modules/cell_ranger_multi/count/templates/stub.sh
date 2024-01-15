#! bash

# run cell ranger multi
echo cellranger multi ${multi_args} \\
	--id=${id} \\
	--description="Cell Ranger (multi) analysis of ${id}" \\
	--csv=config.csv \\
	--jobmode=local --localcores=${task.cpus} --localmem=${task.memory.toGiga()} \\
	--disable-ui

mkdir --parents ${id}/outs/{multi,per_sample_outs}
touch ${id}/outs/config.csv

mkdir --parents ${id}/outs/per_sample_outs/{${expected_datasets},${expected_datasets}}/count
touch ${id}/outs/per_sample_outs/{${expected_datasets},${expected_datasets}}/{metrics_summary.csv,web_summary.html}

# make links to summary reports

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
  task:
    '${task.index}':
      params:
        id: ${id}
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
