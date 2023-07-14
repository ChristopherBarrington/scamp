#! bash

samtools faidx $fasta

# write software versions used in this module
cat <<-VERSIONS > versions.yaml
"${task.process}":
    `samtools help version | head -n 2 | sed 's/Using //' | sed 's/ /: /' | sed 's/^/  /'`
VERSIONS
