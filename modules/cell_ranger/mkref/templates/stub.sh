#! bash

mkdir --parents $assembly/{fasta,genes}
touch $assembly/genes/genes.gtf.gz
touch $assembly/fasta/{genome.fa,genome.fa.fai}

# write task information to a (yaml) file
cat <<-END_TASK > task.yaml
"${task.process}":
    ${task.index}:
        ext:
            mkref: ${mkref_args}
        params:
            assembly: $assembly
            assembly_fasta: `pwd`/assembly.fasta
            features_gtf: `pwd`/parsed_features.gtf
        task:
            work_dir: `pwd`
        versions:
            cell ranger: `cellranger --version | sed 's/cellranger cellranger-//'`
END_TASK
