extends Node

const SERVER_URL := "ws://localhost:8080/ws"
const MAX_USERNAME_LENGTH := 32
const MAX_CHAT_LENGTH := 200

const PLAYER_SCENE := preload("res://scenes/client/player.tscn")

var socket := WebSocketPeer.new()
var connected := false
var other_players: Dictionary = {}
var _spawning: Dictionary = {}

signal on_chat_received(username: String, text: String)

func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--server" in args:
		return
	# Ne rien faire ici — connect_to_server() sera appelé par world.gd

func connect_to_server() -> void:
	if GameState.current_character == null:
		push_error("current_character est null")
		return
	# Reset le socket proprement avant de reconnecter
	socket = WebSocketPeer.new()
	var player_id := str(int(GameState.current_character["id"]))
	var url := SERVER_URL + "?id=" + player_id
	print("Connexion vers: ", url)
	var err := socket.connect_to_url(url)
	if err != OK:
		push_error("Échec connexion WebSocket : %d" % err)
		return
		
func _process(_delta: float) -> void:
	print("process tourne, state: ", socket.get_ready_state())
	socket.poll()
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not connected:
				connected = true
				print("✓ Connecté au serveur Go !")
				_on_connected()
			while socket.get_available_packet_count() > 0:
				_handle_packet(socket.get_packet())
		WebSocketPeer.STATE_CLOSED:
			if connected:
				connected = false
				print("✗ Déconnecté du serveur")
				_cleanup_other_players()

func _on_connected() -> void:
	# Envoie la position initiale
	var player := get_tree().root.get_node_or_null("World/Player")
	if player != null:
		send_move(player.global_position, "idle_down", false)

func _handle_packet(raw: PackedByteArray) -> void:
	var msg = JSON.parse_string(raw.get_string_from_utf8())
	if msg == null:
		return
	print("Paquet reçu: ", msg["type"], " — ", msg)  # ← temporaire
	match msg["type"]:
		"player_joined":
			_spawn_other_player(
				msg["id"], 
				Vector2(float(msg["x"]), float(msg["y"])),
				msg["username"],
				msg.get("anim", "idle_down"),
				bool(msg.get("flip", false))
			)
		"player_moved":
			if other_players.has(msg["id"]):
				_update_other_player(
					other_players[msg["id"]],
					Vector2(float(msg["x"]), float(msg["y"])),
					msg.get("username", ""),
					msg.get("anim", "idle_down"),
					bool(msg.get("flip", false))
				)
		"player_left":
			_remove_player(msg["id"])
		"chat":
			emit_signal("on_chat_received", msg["username"], msg["text"])
		"already_connected":
			push_warning("Personnage déjà connecté !")
			get_tree().change_scene_to_file("res://scenes/client/ui/character_select.tscn")

# ── Envoi ────────────────────────────────────────────────

func send_move(pos: Vector2, anim: String, flip: bool) -> void:
	if not connected:
		return
	var username := ""
	if GameState.current_character != null:
		username = GameState.current_character["character_name"]
	_send({
		"type": "move",
		"payload": {"x": pos.x, "y": pos.y, "anim": anim, "flip": flip, "username": username}
	})

func send_chat_message(text: String) -> void:
	if not connected or text.strip_edges() == "":
		return
	var username: String = GameState.current_character["character_name"] if GameState.current_character else ""
	_send({
		"type": "chat",
		"payload": {
			"username": username.left(MAX_USERNAME_LENGTH),
			"text": text.left(MAX_CHAT_LENGTH)
		}
	})

func _send(data: Dictionary) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	socket.send_text(JSON.stringify(data))

# ── Gestion des autres joueurs ───────────────────────────

func _spawn_other_player(id: String, pos: Vector2, username: String, anim: String, flip: bool) -> void:
	if other_players.has(id) or _spawning.has(id):
		return
	_spawning[id] = true
	var world := get_tree().root.get_node_or_null("World")
	if world == null:
		await get_tree().process_frame
		world = get_tree().root.get_node_or_null("World")
		if world == null:
			_spawning.erase(id)
			return
	var other_player: CharacterBody2D = PLAYER_SCENE.instantiate()
	other_player.is_local = false
	other_player.scale = Vector2(0.5, 0.5)
	other_player.get_node("Camera2D").enabled = false
	other_player.get_node("LabelName").text = username
	other_player.global_position = pos
	world.add_child(other_player)
	other_player.y_sort_enabled = true
	_update_other_player(other_player, pos, username, anim, flip)
	other_players[id] = other_player
	_spawning.erase(id)

func _update_other_player(node: Node, pos: Vector2, username: String, anim: String, flip: bool) -> void:
	node.global_position = pos
	if username != "":
		node.get_node("LabelName").text = username
	var sprite: AnimatedSprite2D = node.get_node("AnimatedSprite2D")
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = flip

func _remove_player(id: String) -> void:
	if other_players.has(id):
		other_players[id].queue_free()
		other_players.erase(id)

func _cleanup_other_players() -> void:
	for node in other_players.values():
		if is_instance_valid(node):
			node.queue_free()
	other_players.clear()
	_spawning.clear()
