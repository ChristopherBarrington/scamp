// merge together multiple emitted channels from a process

include { make_map } from '../make_map'

def merge_process_emissions(channel_list, keys) {
	def ch_out = channel_list.out.(keys.first())
	keys.tail().each{ch_out=ch_out.merge(channel_list.out.(it))}
	ch_out.map{x -> make_map(x, keys)}
}
