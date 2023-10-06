#! bash

touch {versions,task}.yaml $output_file

find -L input_* -regextype posix-extended -regex '$regex' -type f \\
| sort --version-sort \\
> catted_files

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    regex: $regex
    files:
        `sed '2,\$ s/^/        /' catted_files`
    task_index: ${task.index}
    ext:
    versions:
    work_dir: `pwd`
END_TASK
