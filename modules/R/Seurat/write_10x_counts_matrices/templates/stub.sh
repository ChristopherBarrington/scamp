#! bash

touch {counts_matrices,features}.rds

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
  task:
    '${task.index}':
      params:
        feature_identifier: $feature_identifier
      meta:
        workDir: `pwd`
  process:
    ext: []
    versions:
      R: `R --version | head -n 1 | sed --regexp-extended 's/R version (\\S+) .*/\\1/'`
END_TASK
