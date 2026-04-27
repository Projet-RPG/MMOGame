extends Node

func _ready():
	var args = OS.get_cmdline_user_args()
	
	if "--server" in args:
		print("ok")
		get_tree().change_scene_to_file.call_deferred("res://scenes/server/server_main.tscn")
	else:
		print("okk")
		get_tree().change_scene_to_file.call_deferred("res://scenes/client/ui/login.tscn")
