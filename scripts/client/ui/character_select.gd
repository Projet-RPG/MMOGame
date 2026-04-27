extends Control

const API_GET_CHARACTERS := "http://localhost/mmo_api/get_characters.php"
const API_SET_ONLINE := "http://localhost/mmo_api/set_online.php"
const API_DELETE := "http://localhost/mmo_api/delete_character.php"

@onready var label_welcome := $LabelWelcome
@onready var label_error := $LabelError
@onready var label_slots := [
	$HBoxContainer/Slot1/LabelSlot1,
	$HBoxContainer/Slot2/LabelSlot2,
	$HBoxContainer/Slot3/LabelSlot3,
]
@onready var btn_slots := [
	$HBoxContainer/Slot1/BtnSlot1,
	$HBoxContainer/Slot2/BtnSlot2,
	$HBoxContainer/Slot3/BtnSlot3,
]
@onready var btn_play := $HBoxContainer2/BtnPlay
@onready var btn_create := $HBoxContainer2/BtnCreate
@onready var btn_delete := $HBoxContainer2/BtnDelete

var characters: Array = []
var selected_slot := -1


func _ready() -> void:
	label_welcome.text = "Bienvenue, %s !" % GameState.username
	label_error.text = ""
	for i in 3:
		var idx := i
		btn_slots[i].pressed.connect(func(): _select_slot(idx + 1))
	btn_play.pressed.connect(_on_play)
	btn_create.pressed.connect(_on_create)
	btn_delete.pressed.connect(_on_delete)
	_set_buttons_enabled(false)
	_load_characters()


func _update_slots() -> void:
	for i in 3:
		var data := _find_in_slot(i + 1)
		if data.is_empty():
			label_slots[i].text = "Vide"
			btn_slots[i].text = "Vide"
			btn_slots[i].disabled = false
			btn_slots[i].modulate = Color.WHITE
		else:
			var online := int(data.get("is_online", 0)) == 1
			label_slots[i].text = "%s\nNiv. %s" % [data["character_name"], data["level"]]
			btn_slots[i].text = "En jeu" if online else "Sélectionner"
			btn_slots[i].disabled = online
			btn_slots[i].modulate = Color(1.0, 0.4, 0.4) if online else Color.WHITE


func _find_in_slot(slot: int) -> Dictionary:
	for c in characters:
		if int(c["slot"]) == slot:
			return c
	return {}


func _select_slot(slot: int) -> void:
	selected_slot = slot
	label_error.text = "Slot %d sélectionné" % slot


func _load_characters() -> void:
	label_error.text = "Chargement..."
	_do_request(API_GET_CHARACTERS, {"account_id": GameState.account_id}, _on_characters_loaded)


func _on_characters_loaded(_r, _c, _h, body) -> void:
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	label_error.text = ""
	if json == null or not json.get("success", false):
		label_error.text = "Erreur chargement personnages"
		return
	characters = json["characters"]
	_update_slots()
	_set_buttons_enabled(true)


func _on_play() -> void:
	if selected_slot == -1:
		label_error.text = "Sélectionne un personnage !"
		return
	var data := _find_in_slot(selected_slot)
	if data.is_empty():
		label_error.text = "Ce slot est vide !"
		return
	GameState.current_character = data
	_set_buttons_enabled(false)
	_do_request(API_SET_ONLINE,
		{"account_id": GameState.account_id, "slot": selected_slot, "online": 1},
		func(_r, _c, _h, _b): get_tree().change_scene_to_file("res://scenes/client/world.tscn")
	)


func _on_create() -> void:
	if selected_slot == -1:
		label_error.text = "Sélectionne un slot vide !"
		return
	if not _find_in_slot(selected_slot).is_empty():
		label_error.text = "Slot déjà occupé !"
		return
	GameState.selected_slot = selected_slot
	get_tree().change_scene_to_file("res://scenes/ui/character_create.tscn")


func _on_delete() -> void:
	if selected_slot == -1:
		label_error.text = "Sélectionne un personnage !"
		return
	if _find_in_slot(selected_slot).is_empty():
		label_error.text = "Ce slot est vide !"
		return
	_set_buttons_enabled(false)
	_do_request(API_DELETE,
		{"account_id": GameState.account_id, "slot": selected_slot},
		_on_deleted
	)


func _on_deleted(_r, _c, _h, body) -> void:
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.get("success", false):
		label_error.text = json.get("message", "Erreur serveur") if json else "Erreur serveur"
		_set_buttons_enabled(true)
		return
	label_error.text = "Personnage supprimé !"
	selected_slot = -1
	_load_characters()


func _set_buttons_enabled(enabled: bool) -> void:
	btn_play.disabled = not enabled
	btn_create.disabled = not enabled
	btn_delete.disabled = not enabled


func _do_request(url: String, data: Dictionary, callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var err := http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(data))
	if err != OK:
		push_error("Échec requête %s : %d" % [url, err])
		http.queue_free()
