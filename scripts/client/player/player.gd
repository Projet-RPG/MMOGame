extends CharacterBody2D

@export var speed: float = 120.0

var character := Character.new()
var is_local := true

const SAVE_INTERVAL := 10.0
const API_SAVE_URL := "http://localhost/mmo_api/save_position.php"
const ANIM_MAP := {
	Vector2(-1, -1): "walk_up_left",
	Vector2(1, -1):  "walk_up_right",
	Vector2(-1, 1):  "walk_down_left",
	Vector2(1, 1):   "walk_down_right",
	Vector2(-1, 0):  "walk_left",
	Vector2(1, 0):   "walk_right",
	Vector2(0, -1):  "walk_up",
	Vector2(0, 1):   "walk_down",
}
const IDLE_MAP := {
	Vector2(0, 1):   "idle_down",
	Vector2(0, -1):  "idle_up",
	Vector2(-1, 0):  "idle_left",
	Vector2(1, 0):   "idle_right",
	Vector2(-1, 1):  "idle_down_left",
	Vector2(1, 1):   "idle_down_right",
	Vector2(-1, -1): "idle_up_left",
	Vector2(1, -1):  "idle_up_right",
}

var _save_timer := 0.0
var _last_anim := ""
var _idle_dir := Vector2(0, 1)


func _ready() -> void:
	$AnimatedSprite2D.play("idle_down")
	if not is_local:
		set_physics_process(false)
		return
	if GameState.current_character != null:
		character.character_name = GameState.current_character["character_name"]
		character.hp = character.max_hp
	call_deferred("_update_hud")


func _update_hud() -> void:
	var hud := get_node_or_null("/root/World/HUD")
	if hud != null:
		hud.update_hp(character.hp, character.max_hp)


func _get_input_dir() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	return dir


func _physics_process(delta: float) -> void:
	var chat := get_node_or_null("/root/World/Chat")
	if chat != null and chat.is_input_open():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := _get_input_dir()

	# _idle_dir = dernière direction non-nulle des touches encore appuyées
	# Si on appuie sur une touche, on met à jour
	# Si on relâche une touche, on recalcule depuis ce qui reste appuyé
	if dir != Vector2.ZERO:
		_idle_dir = Vector2(sign(dir.x), sign(dir.y))
	else:
		# Recalcule depuis les touches encore enfoncées individuellement
		var remaining := Vector2.ZERO
		if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT):
			remaining.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			remaining.x += 1
		if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP):
			remaining.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			remaining.y += 1
		if remaining != Vector2.ZERO:
			_idle_dir = Vector2(sign(remaining.x), sign(remaining.y))

	velocity = dir.normalized() * speed
	move_and_slide()
	_update_animation(dir)

	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		_save_position()

	var net := get_node_or_null("/root/NetworkClient")
	if net != null:
		net.send_position(global_position, $AnimatedSprite2D.animation, $AnimatedSprite2D.flip_h)


func _update_animation(dir: Vector2) -> void:
	var anim: String
	if dir != Vector2.ZERO:
		anim = ANIM_MAP.get(Vector2(sign(dir.x), sign(dir.y)), "idle_down")
	else:
		anim = IDLE_MAP.get(_idle_dir, "idle_down")

	if anim != _last_anim:
		$AnimatedSprite2D.play(anim)
		$AnimatedSprite2D.flip_h = false
		_last_anim = anim


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_position()


func _save_position() -> void:
	if not is_local or GameState.current_character == null:
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, body):
		print("Position sauvegardée : ", body.get_string_from_utf8())
		http.queue_free()
	)
	var body := JSON.stringify({
		"character_id": GameState.current_character["id"],
		"pos_x": global_position.x,
		"pos_y": global_position.y
	})
	var err := http.request(API_SAVE_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("Échec save_position : %d" % err)
		http.queue_free()
