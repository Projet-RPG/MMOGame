extends Node

const SERVER_IP := "127.0.0.1"
const SERVER_PORT := 7777
const PLAYER_SCENE := preload("res://scenes/client/player.tscn")
const API_ONLINE_URL := "http://localhost/mmo_api/set_online.php"

var connected := false
var other_players: Dictionary = {}
var _spawning: Dictionary = {}


func _ready() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(SERVER_IP, SERVER_PORT)
	if err != OK:
		push_error("Échec de connexion ENet : %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)


func _on_connected() -> void:
	connected = true
	print("✓ Connecté au serveur !")

func _on_failed() -> void:
	push_error("Échec de connexion au serveur")

func _on_disconnected() -> void:
	connected = false
	_cleanup_other_players()
	print("✗ Déconnecté du serveur")
	set_offline()


func set_offline() -> void:
	if GameState.current_character == null:
		return
	var http := HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	var body := JSON.stringify({
		"account_id": GameState.account_id,
		"slot": int(GameState.current_character["slot"]),
		"online": 0
	})
	http.request(API_ONLINE_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	GameState.current_character = null


func send_position(pos: Vector2, anim: String, flip: bool) -> void:
	if not _is_ready():
		return
	receive_position.rpc_id(1, pos, GameState.current_character["character_name"], anim, flip)


func send_chat_message(text: String) -> void:
	if not _is_ready() or text.strip_edges() == "":
		return
	receive_chat.rpc_id(1, GameState.current_character["character_name"], text)


# --- RPCs (identiques client et serveur) ---

@rpc("any_peer", "reliable")
func send_character_id(_character_id: int) -> void:
	pass

@rpc("any_peer", "reliable")
func request_players() -> void:
	pass

@rpc("any_peer", "unreliable_ordered")
func receive_position(_pos: Vector2, _username: String, _anim: String, _flip: bool) -> void:
	pass

@rpc("any_peer", "unreliable")
func receive_chat(_username: String, _text: String) -> void:
	pass

@rpc("any_peer", "reliable")
func request_active_characters() -> void:
	pass

@rpc("any_peer", "reliable")
func character_id_confirmed() -> void:
	print("✓ Character ID confirmé par le serveur")
	var player := get_tree().root.get_node_or_null("World/Player")
	if player != null:
		receive_position.rpc_id(1, player.global_position,
			GameState.current_character["character_name"], "idle_down", false)
	await get_tree().create_timer(0.3).timeout
	request_players.rpc_id(1)

@rpc("any_peer", "reliable")
func character_already_connected() -> void:
	push_warning("Personnage déjà en jeu !")
	connected = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	set_offline()
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

@rpc("any_peer", "unreliable_ordered")
func receive_position_from(sender_id: int, pos: Vector2, username: String, anim: String, flip: bool) -> void:
	if other_players.has(sender_id):
		_update_other_player(other_players[sender_id], pos, username, anim, flip)
		return
	if not _spawning.has(sender_id):
		_spawn_other_player(sender_id, pos, username, anim, flip)

@rpc("any_peer", "unreliable")
func receive_chat_from(username: String, text: String) -> void:
	var chat := get_tree().root.get_node_or_null("World/Chat")
	if chat != null:
		chat.add_message(username, text)

@rpc("any_peer", "reliable")
func remove_player(peer_id: int) -> void:
	if other_players.has(peer_id):
		other_players[peer_id].queue_free()
		other_players.erase(peer_id)

@rpc("any_peer", "reliable")
func receive_active_characters(ids: Array) -> void:
	GameState.active_character_ids = ids
	GameState.active_characters_received.emit()


# --- Helpers ---

func _is_ready() -> bool:
	if not connected:
		return false
	var mp := multiplayer.multiplayer_peer
	return mp != null and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _update_other_player(node: Node, pos: Vector2, username: String, anim: String, flip: bool) -> void:
	node.global_position = pos
	node.get_node("LabelName").text = username
	var sprite: AnimatedSprite2D = node.get_node("AnimatedSprite2D")
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = flip

func _spawn_other_player(sender_id: int, pos: Vector2, username: String, anim: String, flip: bool) -> void:
	_spawning[sender_id] = true
	var world := get_tree().root.get_node_or_null("World")
	if world == null:
		await get_tree().process_frame
		world = get_tree().root.get_node_or_null("World")
		if world == null:
			_spawning.erase(sender_id)
			return
	var other_player: CharacterBody2D = PLAYER_SCENE.instantiate()
	other_player.is_local = false
	other_player.scale = Vector2(0.5, 0.5)
	other_player.get_node("Camera2D").enabled = false
	other_player.get_node("LabelName").text = username
	other_player.global_position = pos
	world.add_child(other_player)
	_update_other_player(other_player, pos, username, anim, flip)
	other_players[sender_id] = other_player
	_spawning.erase(sender_id)

func _cleanup_other_players() -> void:
	for node in other_players.values():
		if is_instance_valid(node):
			node.queue_free()
	other_players.clear()
	_spawning.clear()
