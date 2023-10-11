#! bash

# get comma-separated list of input directories to find fastq files
FASTQ_PATHS=`find -L fastq_path_* -mindepth 1 -maxdepth 1 -name "${sample}_S*_L*_R1_*.fastq.gz" -printf '%h\\n' |
	sort |
	uniq |
	awk '{printf "%s%s", sep, \$1 ; sep=","} END{print ""}'`

# run cell ranger count
cellranger count $count_args \\
	--id=$id \\
	--description="$description" \\
	--transcriptome=`realpath index_path` \\
	--fastqs=\${FASTQ_PATHS} \\
	--sample=$sample \\
	--jobmode=local --localcores=${task.cpus} --localmem=${task.memory.toGiga()} \\
	--disable-ui \\
	--dry

mkdir --parents $id/outs
touch $id/outs/web_summary.html
ln --symbolic $id/outs/web_summary.html

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
'${task.process}':
  task:
    '${task.index}':
      params:
        id: $id
        description: $description
        sample: $sample
        index_path: `realpath index_path`
      meta:
        workDir: `pwd`
  process:
    ext:
      count: $count_args
    versions:
      cell ranger: `cellranger --version | sed 's/cellranger cellranger-//'`
END_TASK
