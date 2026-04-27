extends Node
func _ready():
	var args = OS.get_cmdline_args()
	print("Args : ", args)
	
	if "--server" in args:
		get_tree().change_scene_to_file.call_deferred("res://scenes/server/server_main.tscn")
	else:
		get_tree().change_scene_to_file.call_deferred("res://scenes/client/ui/login.tscn")
