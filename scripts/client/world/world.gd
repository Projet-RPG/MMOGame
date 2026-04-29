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
	NetworkManager.connect_to_server()
	_wait_and_connect()

func _wait_and_connect() -> void:
	# Affiche le message de connexion
	var label := Label.new()
	label.text = "Connexion au serveur..."
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)

	var elapsed := 0.0
	var dots := 0
	while not NetworkManager.connected:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		dots = int(elapsed * 2) % 4
		label.text = "Connexion au serveur" + ".".repeat(dots)
		if elapsed >= 30.0:
			label.text = "Impossible de joindre le serveur !"
			await get_tree().create_timer(2.0).timeout
			label.queue_free()
			push_error("Timeout connexion serveur Go !")
			return

	label.queue_free()
	print("Connexion établie au serveur Go !")
	
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_logout_then_quit()

func _logout_then_quit() -> void:
	if GameState.current_character == null:
		get_tree().quit()
		return
	NetworkManager.socket.close()
	NetworkManager.connected = false
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
