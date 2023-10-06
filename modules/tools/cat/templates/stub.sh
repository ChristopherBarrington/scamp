#! bash

touch {versions,task}.yaml $output_file

find -L input_* -regextype posix-extended -regex '$regex' -type f \\
| sort --version-sort \\
> catted_files

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    ${task.index}:
        ext:
        params:
            regex: "$regex"
            files:
                `sed '2,\$ s/^/                /' catted_files`
        task:
            work_dir: `pwd`
        versions:
END_TASK
