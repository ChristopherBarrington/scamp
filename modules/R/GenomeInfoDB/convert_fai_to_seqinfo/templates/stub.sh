#! bash

touch $output_seqinfo

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
  task:
    '${task.index}':
      params:
        genome_name: $genome_name
        fai_file: $fai_file
      meta:
        workDir: `pwd`
  process:
    ext: []
    versions:
      R: `R --version | head -n 1 | sed --regexp-extended 's/R version (\\S+) .*/\\1/'`
END_TASK
