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
	print("╔══════════════════════════════╗")
	print("║  ⚡ Serveur démarré !         ║")
	print("║  Port    : ", PORT, "              ║")
	print("║  MaxConn : ", MAX_CLIENTS, "            ║")
	print("╚══════════════════════════════╝")

func _on_peer_connected(id: int) -> void:
	players[id] = {
		"pos": Vector2.ZERO,
		"character_id": 0,
		"username": "",
		"anim": "idle_down",
		"flip": false
	}
	print("┌─────────────────────────────┐")
	print("│ ✓ Joueur connecté !          │")
	print("│   peer_id : ", id)
	print("│   Total   : ", players.size(), " joueur(s)")
	print("└─────────────────────────────┘")

func _on_peer_disconnected(id: int) -> void:
	if not players.has(id):
		return
	print("┌─────────────────────────────┐")
	print("│ ✗ Joueur déconnecté !        │")
	print("│   peer_id : ", id)
	print("└─────────────────────────────┘")
	var data: Dictionary = players[id]
	if data["character_id"] != 0:
		_save_position(data)
	var network_client := get_node_or_null("/root/NetworkClient")
	if network_client != null:
		for peer_id in players:
			if peer_id != id:
				network_client.remove_player.rpc_id(peer_id, id)
	players.erase(id)
	print("  → Joueurs restants : ", players.size())

func _save_position(data: Dictionary) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, body):
		print("  → Position sauvegardée : ", body.get_string_from_utf8())
		http.queue_free()
	)
	var body := JSON.stringify({
		"character_id": data["character_id"],
		"pos_x": data["pos"].x,
		"pos_y": data["pos"].y
	})
	var err := http.request(API_SAVE_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("Échec de la requête save_position : %d" % err)
		http.queue_free()

func get_connected_character_ids() -> Array:
	var ids: Array = []
	for peer_id in players:
		var cid: int = players[peer_id]["character_id"]
		if cid != 0:
			ids.append(cid)
	return ids
