#! bash

analysis_tool --sample $sample --database db --parameter 100 --output intermediate.file
cat intermediate.file | parsing_tool > output.file

# write software versions used in this module
cat <<-VERSIONS > versions.yaml
"${task.process}":
    analysis tool: `analysis_tool --version`
    parsing tool: `parsing_tool -v`
VERSIONS

# write parameters to a (yaml) file
cat <<-TASK > task.yaml
"${task.process}":
    sample: $sample
    work_dir: `pwd`
TASK
