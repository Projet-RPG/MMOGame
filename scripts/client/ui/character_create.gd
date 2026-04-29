extends Control

const API_CREATE := "http://localhost/mmo_api/create_character.php"
const CLASS_STATS := {
	"Guerrier": {"hp": 150, "strength": 20, "intelligence": 5},
	"Mage":     {"hp": 80,  "strength": 5,  "intelligence": 25},
	"Archer":   {"hp": 100, "strength": 15, "intelligence": 10},
}

@onready var input_name := $VBoxContainer/InputName
@onready var label_class := $VBoxContainer/LabelClass
@onready var label_stats := $VBoxContainer/LabelStats
@onready var label_error := $VBoxContainer/LabelError
@onready var btn_confirm := $VBoxContainer/BtnConfirm

var selected_class := ""


func _ready() -> void:
	label_error.text = ""
	label_stats.text = ""
	$VBoxContainer/HBoxContainer/BtnGuerriero.pressed.connect(func(): _select_class("Guerrier"))
	$VBoxContainer/HBoxContainer/BtnMage.pressed.connect(func(): _select_class("Mage"))
	$VBoxContainer/HBoxContainer/BtnArcher.pressed.connect(func(): _select_class("Archer"))
	btn_confirm.pressed.connect(_on_confirm)


func _select_class(cls: String) -> void:
	selected_class = cls
	label_class.text = "Classe : " + cls
	var s : Dictionary = CLASS_STATS[cls]
	label_stats.text = "HP : %d | Force : %d | Intelligence : %d" % [s["hp"], s["strength"], s["intelligence"]]


func _on_confirm() -> void:
	var char_name : String = input_name.text.strip_edges()
	if char_name == "":
		label_error.text = "Entre un nom !"
		return
	if selected_class == "":
		label_error.text = "Choisis une classe !"
		return
	btn_confirm.disabled = true
	label_error.text = ""
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_created)
	var body := JSON.stringify({
		"account_id": GameState.account_id,
		"character_name": char_name,
		"slot": GameState.selected_slot,
		"class": selected_class
	})
	var err := http.request(API_CREATE, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("Échec create_character : %d" % err)
		label_error.text = "Erreur réseau"
		btn_confirm.disabled = false
		http.queue_free()


func _on_created(_r, _c, _h, body) -> void:
	btn_confirm.disabled = false
	var json : Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		label_error.text = "Erreur serveur"
		return
	if json.get("success", false):
		get_tree().change_scene_to_file("res://scenes/client/ui/character_select.tscn")
	else:
		label_error.text = json.get("message", "Erreur inconnue")
