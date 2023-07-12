#! bash

touch {task,versions}.yaml

mkdir --parents $assembly/{fasta,genes}
touch $assembly/genes/genes.gtf.gz
touch $assembly/fasta/{genome.fa,genome.fa.fai}
