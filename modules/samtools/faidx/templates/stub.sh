#! bash

touch ${fasta}.fai

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
    '${task.index}':
        ext:
        params:
            fasta: $fasta
        versions:
            `samtools help version | head -n 2 | sed 's/Using //' | sed 's/ /: /' | sed '2,\$ s/^/            /'`
        task:
            work_dir: `pwd`
END_TASK

