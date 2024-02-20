// merge together multiple emitted channels from a process

include { concatenate_maps_list } from '../concatenate_maps_list'

def merge_process_emissions(process, keys) {
	def ch_out = process.out.(keys.first()).map{[(keys.first()): it]}
	keys.tail().each{k -> ch_out = ch_out.merge(process.out.(k).map{[(k): it]})}
	ch_out.map{concatenate_maps_list(it)}
}

