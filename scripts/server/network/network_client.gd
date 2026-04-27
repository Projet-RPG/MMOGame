extends Node

const MAX_USERNAME_LENGTH := 32
const MAX_CHAT_LENGTH := 200


# --- RPCs (identiques client et serveur) ---

@rpc("any_peer", "reliable")
func send_character_id(character_id: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if character_id <= 0:
		_kick(sender_id)
		return
	print("┌─────────────────────────────┐")
	print("│ → Character ID reçu          │")
	print("│   peer_id      : ", sender_id)
	print("│   character_id : ", character_id)
	print("└─────────────────────────────┘")
	var server_main := _get_server_main()
	if server_main == null or not server_main.players.has(sender_id):
		return
	for peer_id in server_main.players:
		if peer_id != sender_id and server_main.players[peer_id]["character_id"] == character_id:
			print("  ✗ Character déjà connecté ! Kick peer ", sender_id)
			character_already_connected.rpc_id(sender_id)
			await get_tree().create_timer(0.1).timeout
			_kick(sender_id)
			return
	server_main.players[sender_id]["character_id"] = character_id
	print("  ✓ Character ID enregistré !")
	character_id_confirmed.rpc_id(sender_id)


@rpc("any_peer", "reliable")
func request_players() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var server_main := _get_server_main()
	if server_main == null:
		return
	var count := 0
	for peer_id in server_main.players:
		if peer_id == sender_id:
			continue
		var data: Dictionary = server_main.players[peer_id]
		if data["username"] == "" or data["character_id"] == 0:
			continue
		count += 1
		receive_position_from.rpc_id(
			sender_id, peer_id, data["pos"],
			data["username"], data.get("anim", "idle_down"), data.get("flip", false)
		)
	print("  → ", count, " joueur(s) envoyé(s) à peer ", sender_id)


@rpc("any_peer", "unreliable_ordered")
func receive_position(pos: Vector2, username: String, anim: String, flip: bool) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var server_main := _get_server_main()
	if server_main == null or not server_main.players.has(sender_id):
		return
	var valid_anims := ["idle_down","walk_down","walk_up","walk_left","walk_right",
						"walk_down_left","walk_down_right","walk_up_left","walk_up_right"]
	server_main.players[sender_id]["pos"] = pos
	server_main.players[sender_id]["username"] = username.left(MAX_USERNAME_LENGTH)
	server_main.players[sender_id]["anim"] = anim if anim in valid_anims else "idle_down"
	server_main.players[sender_id]["flip"] = flip
	for peer_id in server_main.players:
		if peer_id != sender_id:
			receive_position_from.rpc_id(
				peer_id, sender_id, pos,
				server_main.players[sender_id]["username"],
				server_main.players[sender_id]["anim"],
				flip
			)


@rpc("any_peer", "unreliable")
func receive_chat(username: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	var sanitized: String = text.left(MAX_CHAT_LENGTH)
	var san_user: String = username.left(MAX_USERNAME_LENGTH)
	print("  → Chat de ", san_user, " : ", sanitized)
	var server_main := _get_server_main()
	if server_main == null:
		return
	for peer_id in server_main.players:
		receive_chat_from.rpc_id(peer_id, san_user, sanitized)


@rpc("any_peer", "reliable")
func request_active_characters() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var server_main := _get_server_main()
	if server_main == null:
		return
	var active_ids: Array = []
	for peer_id in server_main.players:
		var cid: int = server_main.players[peer_id]["character_id"]
		if cid != 0:
			active_ids.append(cid)
	receive_active_characters.rpc_id(sender_id, active_ids)


@rpc("any_peer", "reliable")
func character_id_confirmed() -> void:
	pass

@rpc("any_peer", "reliable")
func character_already_connected() -> void:
	pass

@rpc("any_peer", "unreliable_ordered")
func receive_position_from(_sender_id: int, _pos: Vector2, _username: String, _anim: String, _flip: bool) -> void:
	pass

@rpc("any_peer", "unreliable")
func receive_chat_from(_username: String, _text: String) -> void:
	pass

@rpc("any_peer", "reliable")
func remove_player(_peer_id: int) -> void:
	pass

@rpc("any_peer", "reliable")
func receive_active_characters(_ids: Array) -> void:
	pass


# --- Helpers ---

func _get_server_main() -> Node:
	return get_node_or_null("/root/ServerMain")

func _kick(peer_id: int) -> void:
	var mp := multiplayer.multiplayer_peer
	if mp != null and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		mp.disconnect_peer(peer_id)
