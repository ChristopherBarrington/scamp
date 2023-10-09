#! bash

touch ${fasta}.fai

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
  task:
    '${task.index}':
      params:
        fasta: $fasta
      meta:
        work_dir: `pwd`
  process:
    ext: []
    versions:
      `samtools help version | head -n 2 | sed 's/Using //' | sed 's/ /: /' | sed '2,\$ s/^/      /'`
END_TASK
