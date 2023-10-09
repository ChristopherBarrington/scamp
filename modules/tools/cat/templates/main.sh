#! bash

find -L input_* -regextype posix-extended -regex '$regex' -type f \\
| sort --version-sort \\
| tee catted_files \\
| xargs cat > $output_file

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
        work_dir: `pwd`
  process:
    ext: []
    versions: []
END_TASK
