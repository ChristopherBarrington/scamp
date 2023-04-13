// create a list of genomes used in this project
// -- returns a list of maps, one for each genome
// ++ find a genome: genomes.find{it.'genome name'=='mouse'}
// ++ add an element to a specific genome: genomes.find{it.'genome name'=='mouse'}.put('foo','bar')

include { convert_map_keys_to_files } from '../convert_map_keys_to_files'
include { pluck }                     from '../pluck'

def get_genomes_params() {
	pluck(params, ['project', 'genomes'])
		.collectEntries{genome_name, genome_parameters -> [genome_name, genome_parameters+['genome': genome_name, 'unique id': genome_name]]}
		// .collectEntries{genome_name, genome_parameters -> [genome_name, genome_parameters+['md5sum': genome_parameters.toString().md5()]]}
		.collectEntries{genome_name, genome_parameters -> [genome_name, convert_map_keys_to_files(genome_parameters, ['fasta files', 'gtf files', 'motifs', 'mitochondrial features'])]}
}
