extends Control

const API_LOGIN := "http://localhost/mmo_api/login.php"
const API_REGISTER := "http://localhost/mmo_api/register.php"

@onready var input_username := $"Full Rect/Panel/MarginContainer/VBoxContainer/InputUsername"
@onready var input_password := $"Full Rect/Panel/MarginContainer/VBoxContainer/InputPassword"
@onready var label_error := $"Full Rect/Panel/MarginContainer/VBoxContainer/LabelError"
@onready var btn_login := $"Full Rect/Panel/MarginContainer/VBoxContainer/BtnLogin"
@onready var btn_register := $"Full Rect/Panel/MarginContainer/VBoxContainer/BtnRegister"
@onready var label_login := $"Full Rect/Panel/MarginContainer/VBoxContainer/LabelLogin"
@onready var panel := $"Full Rect/Panel"
@onready var background := $Background

const COLOR_GOLD := Color(0.95, 0.75, 0.1)
const COLOR_DARK_GOLD := Color(0.6, 0.45, 0.05)
const COLOR_BG_PANEL := Color(0.05, 0.04, 0.02, 0.95)
const COLOR_BORDER := Color(0.7, 0.55, 0.1)
const COLOR_INPUT_BG := Color(0.08, 0.06, 0.03)
const COLOR_ERROR := Color(0.9, 0.2, 0.2)

var _stars : Array = []

func _ready() -> void:
	label_error.visible = false
	btn_login.pressed.connect(_on_login)
	btn_register.pressed.connect(_on_register)

	_setup_stars()
	_style_panel()
	_style_label(label_login, "Connexion")
	_style_input(input_username)
	_style_input(input_password)
	_style_btn_primary(btn_login)
	_style_btn_secondary(btn_register)
	_style_error_label(label_error)


func _setup_stars() -> void:
	for i in 60:
		var star := ColorRect.new()
		var sz := randf_range(1.0, 3.0)
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf_range(0, 900), randf_range(0, 600))
		star.color = Color(1, 1, 1, randf_range(0.1, 0.6))
		background.add_child(star)
		_stars.append({
			"node": star,
			"speed": randf_range(10.0, 40.0),
			"dir": Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized(),
			"base_alpha": randf_range(0.1, 0.6),
			"flicker_speed": randf_range(0.5, 2.0),
			"flicker_offset": randf_range(0.0, TAU),
		})


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for s in _stars:
		var node: ColorRect = s["node"]
		# Déplacement
		node.position += s["dir"] * s["speed"] * delta
		# Wrap autour de l'écran
		if node.position.x > 900:
			node.position.x = 0
		elif node.position.x < 0:
			node.position.x = 900
		if node.position.y > 600:
			node.position.y = 0
		elif node.position.y < 0:
			node.position.y = 600
		# Scintillement
		var alpha: float = s["base_alpha"] * (0.6 + 0.4 * sin(t * s["flicker_speed"] + s["flicker_offset"]))
		node.color = Color(1, 1, 1, alpha)


func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.7, 0.55, 0.1, 0.4)
	style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", style)


func _style_label(label: Label, text: String) -> void:
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_GOLD)
	label.add_theme_font_size_override("font_size", 16)


func _style_input(input: LineEdit) -> void:
	input.custom_minimum_size = Vector2(0, 42)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_INPUT_BG
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	input.add_theme_stylebox_override("normal", normal)

	var focus := StyleBoxFlat.new()
	focus.bg_color = COLOR_INPUT_BG
	focus.border_color = COLOR_GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	focus.content_margin_left = 10
	focus.content_margin_right = 10
	focus.content_margin_top = 8
	focus.content_margin_bottom = 8
	input.add_theme_stylebox_override("focus", focus)

	input.add_theme_color_override("font_color", COLOR_GOLD)
	input.add_theme_color_override("font_placeholder_color", COLOR_DARK_GOLD)
	input.add_theme_font_size_override("font_size", 14)


func _style_btn_primary(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.08, 0.05, 0.01))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.03, 0.005))
	btn.add_theme_color_override("font_pressed_color", Color(0.05, 0.03, 0.005))

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_GOLD
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.border_color = Color(1.0, 0.92, 0.3)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.85, 0.15)
	hover.set_corner_radius_all(4)
	hover.set_border_width_all(1)
	hover.border_color = Color(1.0, 0.95, 0.5)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = COLOR_DARK_GOLD
	pressed.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.4, 0.32, 0.05)
	disabled.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("disabled", disabled)


func _style_btn_secondary(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", COLOR_GOLD)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.3))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.08, 0.02)
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.border_color = COLOR_DARK_GOLD
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.15, 0.11, 0.03)
	hover.set_corner_radius_all(4)
	hover.set_border_width_all(1)
	hover.border_color = COLOR_GOLD
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.07, 0.05, 0.01)
	pressed.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed)


func _style_error_label(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_ERROR)
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD


func _show_error(text: String) -> void:
	label_error.text = text
	label_error.visible = true


func _hide_error() -> void:
	label_error.visible = false
	label_error.text = ""


func _on_login() -> void:
	var username: String = input_username.text.strip_edges()
	var password: String = input_password.text.strip_edges()
	if not _validate(username, password):
		return
	_hide_error()
	_set_buttons_enabled(false)
	_send_request(API_LOGIN, {"username": username, "password": password}, _on_login_response)


func _on_login_response(_result, _code, _headers, body) -> void:
	_set_buttons_enabled(true)
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not _check_response(json):
		return
	GameState.account_id = json["account_id"]
	GameState.username = input_username.text.strip_edges()
	ResourceLoader.load_threaded_request("res://scenes/client/world.tscn")
	get_tree().change_scene_to_file("res://scenes/client/ui/character_select.tscn")


func _on_register() -> void:
	var username: String = input_username.text.strip_edges()
	var password: String = input_password.text.strip_edges()
	if not _validate(username, password):
		return
	_hide_error()
	_set_buttons_enabled(false)
	_send_request(API_REGISTER, {"username": username, "password": password}, _on_register_response)


func _on_register_response(_result, _code, _headers, body) -> void:
	_set_buttons_enabled(true)
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		_show_error("Erreur serveur")
		return
	if json.get("success", false):
		label_error.add_theme_color_override("font_color", COLOR_GOLD)
		_show_error("Compte créé ! Tu peux te connecter.")
	else:
		label_error.add_theme_color_override("font_color", COLOR_ERROR)
		_show_error(json.get("message", "Erreur inconnue"))


func _validate(username: String, password: String) -> bool:
	if username == "" or password == "":
		_show_error("Remplis tous les champs !")
		return false
	return true


func _check_response(json: Variant) -> bool:
	if json == null:
		_show_error("Erreur serveur")
		return false
	if not json.get("success", false):
		_show_error(json.get("message", "Erreur inconnue"))
		return false
	return true


func _send_request(url: String, data: Dictionary, callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var err := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(data))
	if err != OK:
		push_error("Échec requête %s : %d" % [url, err])
		_show_error("Erreur réseau")
		http.queue_free()
		_set_buttons_enabled(true)


func _set_buttons_enabled(enabled: bool) -> void:
	btn_login.disabled = not enabled
	btn_register.disabled = not enabled
