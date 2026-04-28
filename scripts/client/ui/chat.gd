extends VBoxContainer

const MESSAGE_LIFETIME := 10.0
const FADE_DURATION := 1.0
const MAX_MESSAGES := 20

@onready var messages := $ScrollContainer/Messages
@onready var input_message := $HBoxContainer/InputMessage
@onready var input_container := $HBoxContainer
@onready var scroll := $ScrollContainer

var _fade_timer := 0.0
var _is_fading := false
var _chat_visible := true

func _ready() -> void:
	$HBoxContainer/BtnSend.pressed.connect(_on_send)
	input_message.text_submitted.connect(_on_text_submitted)
	input_container.visible = false

func _process(delta: float) -> void:
	if input_container.visible or not _chat_visible:
		return
	_fade_timer -= delta
	if _fade_timer <= 0.0 and not _is_fading:
		_is_fading = true
	if _is_fading:
		scroll.modulate.a = maxf(scroll.modulate.a - delta / FADE_DURATION, 0.0)
		if scroll.modulate.a <= 0.0:
			_is_fading = false
			_chat_visible = false

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_ENTER and not input_container.visible:
		_reset_visibility()
		input_container.visible = true
		input_message.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and input_container.visible:
		input_container.visible = false
		_fade_timer = MESSAGE_LIFETIME

func is_input_open() -> bool:
	return input_container.visible

func add_message(username: String, text: String) -> void:
	var label := Label.new()
	label.text = "%s : %s" % [username, text]
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	messages.add_child(label)
	if messages.get_child_count() > MAX_MESSAGES:
		messages.get_child(0).queue_free()
	_reset_visibility()
	await get_tree().process_frame
	scroll.scroll_vertical = 999999

func _on_text_submitted(_text: String) -> void:
	_send_message()

func _on_send() -> void:
	_send_message()

func _send_message() -> void:
	var text: String = input_message.text.strip_edges()
	input_container.visible = false
	_fade_timer = MESSAGE_LIFETIME
	if text == "":
		return
	input_message.text = ""
	NetworkClient.send_chat_message(text)

func _reset_visibility() -> void:
	_is_fading = false
	_chat_visible = true
	_fade_timer = MESSAGE_LIFETIME
	scroll.modulate.a = 1.0
