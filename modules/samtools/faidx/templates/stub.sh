#! bash

touch versions.yaml ${fasta}.fai

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    fasta: $fasta
    task_index: ${task.index}
    ext:
    versions:
        `samtools help version | head -n 2 | sed 's/Using //' | sed 's/ /: /' | sed '2,\$ s/^/        /'`
    work_dir: `pwd`
END_TASK
