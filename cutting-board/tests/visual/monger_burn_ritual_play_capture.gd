extends Node3D

const VILLAGE := preload("res://scenes/levels/village.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const MASK := preload("res://resources/items/villager_mask.tres")


func _ready() -> void:
	var village := VILLAGE.instantiate()
	add_child(village)
	var monger := village.get_node("Market/MaskMonger") as Npc
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(30, 1, 30)
	slab.add_child(shape)
	add_child(slab)
	slab.global_position = Vector3(monger.global_position.x, -0.5, monger.global_position.z)
	var player := PLAYER.instantiate()
	add_child(player)
	player.global_position = monger.to_global(Vector3(0.3, 0.05, -2.4))
	player.look_at(Vector3(monger.global_position.x, player.global_position.y,
			monger.global_position.z))
	(player.get_node("%CameraPivot") as Node3D).rotation.x = 0.12
	await get_tree().physics_frame
	var interactor := player.get_node("%Interactor") as Interactor
	interactor.spawn_into_hand(MASK, -1, player.get_node("%HandSlotRight"))
	for i in 60:
		await get_tree().process_frame
	(monger.get_node("%Usable") as MaskBurnRitual).use(player)
	await get_tree().create_timer(MaskBurnRitual.SET_DOWN).timeout
	var pivot := player.get_node("%CameraPivot") as Node3D
	create_tween().tween_property(pivot, "rotation:x", -1.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await (monger.get_node("%Usable") as MaskBurnRitual).ritual_finished
	print("player %s monger %s" % [player.global_position, monger.global_position])
	for node in find_children("*", "RigidBody3D", true, false):
		if node.scene_file_path.ends_with("soul_bottle.tscn"):
			print("bottle %s" % node.global_position)
