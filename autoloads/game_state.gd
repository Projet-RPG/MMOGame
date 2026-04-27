extends Node

var account_id : int = 0
var username : String = ""
var current_character = null
var selected_slot : int = 1
var world_preloaded := false
var active_character_ids := []
signal active_characters_received
