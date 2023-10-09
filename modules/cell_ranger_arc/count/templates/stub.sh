#! bash

mkdir --parents $id/outs
touch libraries.csv $id/outs/web_summary.html
touch {atac_summary,joint_summary,rna_summary}.html

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
  task:
    '${task.index}':
      params:
        id: $id
        samples: $samples
        description: $description
        index_path: `realpath index_path`
        complete_libraries `realpath all_libraries.csv`
      meta:
        workDir: `pwd`
  process:
    ext:
      count: ${count_args}
    versions:
      cell ranger arc: `cellranger-arc --version | sed 's/cellranger-arc cellranger-arc-//'`
END_TASK
