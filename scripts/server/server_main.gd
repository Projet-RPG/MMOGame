extends Node

const PORT := 7777
const MAX_CLIENTS := 200
const API_SAVE_URL := "http://localhost/mmo_api/save_position.php"

var players: Dictionary = {}

func _ready() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("Impossible de démarrer le serveur : erreur %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Serveur démarré ! Port : ", PORT)

func _on_peer_connected(id: int) -> void:
	players[id] = {"pos": Vector2.ZERO, "character_id": 0, "username": "", "anim": "idle_down", "flip": false}
	print("Joueur connecté : ", id, " | Total : ", players.size())

func _on_peer_disconnected(id: int) -> void:
	if not players.has(id):
		return
	var data: Dictionary = players[id]
	if data["character_id"] != 0:
		_save_position(data)
	for peer_id in players:
		if peer_id != id:
			remove_player.rpc_id(peer_id, id)
	players.erase(id)
	print("Joueur déconnecté : ", id, " | Restants : ", players.size())

@rpc("any_peer", "reliable")
func send_character_id(character_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender):
		return
	for peer_id in players:
		if peer_id != sender and players[peer_id]["character_id"] == character_id:
			character_already_connected.rpc_id(sender)
			return
	players[sender]["character_id"] = character_id
	character_id_confirmed.rpc_id(sender)
	print("Character ID ", character_id, " assigné à peer ", sender)

@rpc("any_peer", "unreliable_ordered")
func receive_position(pos: Vector2, username: String, anim: String, flip: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender):
		return
	players[sender]["pos"] = pos
	players[sender]["username"] = username
	players[sender]["anim"] = anim
	players[sender]["flip"] = flip
	for peer_id in players:
		if peer_id != sender:
			receive_position_from.rpc_id(peer_id, sender, pos, username, anim, flip)

@rpc("any_peer", "reliable")
func request_players() -> void:
	var sender := multiplayer.get_remote_sender_id()
	for peer_id in players:
		if peer_id != sender and players[peer_id]["username"] != "":
			var d: Dictionary = players[peer_id]
			receive_position_from.rpc_id(sender, peer_id, d["pos"], d["username"], d["anim"], d["flip"])

@rpc("any_peer", "reliable")
func receive_chat(username: String, text: String) -> void:
	for peer_id in players:
		receive_chat_from.rpc_id(peer_id, username, text)

@rpc("any_peer", "reliable")
func receive_position_from(_sender_id: int, _pos: Vector2, _username: String, _anim: String, _flip: bool) -> void:
	pass

@rpc("any_peer", "reliable")
func receive_chat_from(_username: String, _text: String) -> void:
	pass

@rpc("any_peer", "reliable")
func character_id_confirmed() -> void:
	pass

@rpc("any_peer", "reliable")
func character_already_connected() -> void:
	pass

@rpc("any_peer", "reliable")
func remove_player(_peer_id: int) -> void:
	pass

func _save_position(data: Dictionary) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, body):
		print("Position sauvegardée : ", body.get_string_from_utf8())
		http.queue_free()
	)
	var body := JSON.stringify({
		"character_id": data["character_id"],
		"pos_x": data["pos"].x,
		"pos_y": data["pos"].y
	})
	var err := http.request(API_SAVE_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("Echec save_position : %d" % err)
		http.queue_free()

func get_connected_character_ids() -> Array:
	var ids: Array = []
	for peer_id in players:
		var cid: int = players[peer_id]["character_id"]
		if cid != 0:
			ids.append(cid)
	return ids
