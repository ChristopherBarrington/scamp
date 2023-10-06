#! bash

mkdir --parents $id/outs
touch libraries.csv $id/outs/web_summary.html
touch {task,versions}.yaml
touch {atac_summary,joint_summary,rna_summary}.html

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    ${task.index}:
        ext:
            count: ${count_args}
        params:
            id: $id
            samples: $samples
            description: $description
            index_path: `realpath index_path`
            complete_libraries `realpath all_libraries.csv`
        task:
            work_dir: `pwd`
        versions:
            cell ranger arc: `cellranger-arc --version | sed 's/cellranger-arc cellranger-arc-//'`
END_TASK
