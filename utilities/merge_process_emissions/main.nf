// merge together multiple emitted channels from a process

include { make_map } from '../make_map'

def merge_process_emissions(process, keys) {
	def ch_out = process.out.(keys.first())
	keys.tail().each{ch_out=ch_out.merge(process.out.(it))}
	ch_out.map{x -> make_map(x, keys)}
}
