extends Node2D

const API_ONLINE_URL := "http://localhost/mmo_api/set_online.php"

@onready var hud := $HUD
@onready var player := $Player

func _ready() -> void:
	print("World chargé !")
	y_sort_enabled = true
	get_tree().set_auto_accept_quit(false)
	if GameState.current_character == null:
		push_warning("World chargé sans personnage courant !")
		return
	player.global_position = Vector2(
		float(GameState.current_character.get("pos_x", 0)),
		float(GameState.current_character.get("pos_y", 0))
	)
	_wait_and_register()

func _wait_and_register() -> void:
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(NetworkClient):
		push_error("NetworkClient introuvable !")
		return
	var elapsed := 0.0
	while not NetworkClient.connected:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed >= 10.0:
			push_error("Timeout connexion serveur !")
			return
	print("Connexion établie, envoi du character_id...")
	NetworkClient.send_character_id(int(GameState.current_character["id"]))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_logout_then_quit()

func _logout_then_quit() -> void:
	if GameState.current_character == null:
		get_tree().quit()
		return
	NetworkClient.connected = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): get_tree().quit())
	var body := JSON.stringify({
		"account_id": GameState.account_id,
		"slot": int(GameState.current_character["slot"]),
		"online": 0
	})
	GameState.current_character = null
	var err := http.request(API_ONLINE_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		get_tree().quit()

func update_hud(hp: int, max_hp: int) -> void:
	hud.update_hp(hp, max_hp)
