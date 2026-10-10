extends Node

const LEVEL := preload("res://scenes/levels/test_level.tscn")

var _shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await _frames(10)
	var player: Node3D = level.get_node("Player")
	var monger: Node3D = get_tree().get_first_node_in_group(MaskBeacon.GROUP).get_parent()
	monger.process_mode = Node.PROCESS_MODE_DISABLED
	var from := monger.global_position + Vector3(2.5, 0.0, 4.0)
	player.global_position = from
	player.look_at(Vector3(monger.global_position.x, from.y, monger.global_position.z))
	player.set_physics_process(false)
	await _frames(20)
	_save("masked")
	player.equipment.unequip(Equipment.Slot.MASK)
	await _frames(60)
	_save("bare_faced")
	get_tree().quit()


func _save(shot: String) -> void:
	if _shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot + ".png"))
	print("saved ", shot)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
