extends Node

const PORT := 7777
const MAX_CLIENTS := 200
const API_SAVE_URL := "http://localhost/mmo_api/save_position.php"
const API_RESET_ONLINE := "http://localhost/mmo_api/reset_online.php"

var players: Dictionary = {}

func _ready() -> void:
	_reset_all_online()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("Impossible de démarrer le serveur : erreur %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Serveur démarré ! Port : ", PORT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_CRASH:
		_save_all_positions()
		get_tree().quit()

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
			NetworkClient.remove_player.rpc_id(peer_id, id)
	players.erase(id)
	print("Joueur déconnecté : ", id, " | Restants : ", players.size())

func _save_all_positions() -> void:
	for peer_id in players:
		var data: Dictionary = players[peer_id]
		if data["character_id"] != 0:
			_save_position(data)

func _reset_all_online() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	http.request(API_RESET_ONLINE, [], HTTPClient.METHOD_POST, "")

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
