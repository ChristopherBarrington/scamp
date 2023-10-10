#! bash

yq eval-all '. as \$item ireduce ({}; . * \$item )' input_* > $output_file

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
  task:
    '${task.index}':
      params:
        regex: "$regex"
        files:
          - `sed '2,\$ s/^/          - /' catted_files`
      meta:
        workDir: `pwd`
  process:
    ext: []
    versions:
      yq: `yq --version | sed 's/.*v//'`
END_TASK
