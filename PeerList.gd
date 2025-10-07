extends MarginContainer
class_name PeerList

@export var Titel : Label
@export var List : Label

var eos_peer : EOSGMultiplayerPeer

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if eos_peer:
		List.text = ""
		
		var peers : Dictionary = eos_peer.get_all_peers()
		for peer in peers:
			List.text += "Peer ID: %d | User ID: %s \n" % [peer, peers[peer]]
