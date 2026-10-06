extends Node3D

## Headless checks for the Mask-Monger showing through the mask-off grain: while the
## player is bare-faced the beacon render runs, follows the game camera and the Monger
## hums; with a mask on both are off. Prints PASS/FAIL per check and quits with the
## number of failures as the exit code.
##
##   godot --headless --fixed-fps 60 --path cutting-board res://tests/mask_beacon_check.tscn

const PLAYER := preload("res://scenes/characters/player.tscn")
const MONGER := preload("res://scenes/characters/mask_monger.tscn")
const PLAYER_MASK := preload("res://resources/items/player_mask.tres")
const MASK := Equipment.Slot.MASK

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player = PLAYER.instantiate()
	add_child(player)
	# No floor here: hold the player still so the camera does not fall between frames.
	player.set_physics_process(false)
	var monger: Node3D = MONGER.instantiate()
	add_child(monger)
	monger.global_position = Vector3(0, 0, -6)
	var equipment: Equipment = player.equipment
	var vision: MaskOffVision = player.get_node("MaskOffVision")
	var render: SubViewport = vision.get_node("%BeaconRender")
	var beacon_camera: Camera3D = vision.get_node("%BeaconCamera")
	var beacon: MaskBeacon = monger.get_node("%MaskBeacon")
	var hum: AudioStreamPlayer3D = beacon.get_node("%Hum")
	await _frames(2)

	var tagged := beacon.visual.find_children("*", "GeometryInstance3D", true, false)
	var all_tagged := not tagged.is_empty()
	for mesh: GeometryInstance3D in tagged:
		all_tagged = all_tagged and mesh.get_layer_mask_value(MaskBeacon.LAYER)
	_check("the Monger's meshes are on the beacon layer", all_tagged)
	_check("masked: no beacon render, no hum",
			render.render_target_update_mode == SubViewport.UPDATE_DISABLED and not hum.playing)

	equipment.unequip(MASK)
	await _seconds(0.8)
	# Compare once this frame has processed, just before it is drawn.
	var camera := get_viewport().get_camera_3d()
	_check("bare face: the beacon render runs",
			render.render_target_update_mode == SubViewport.UPDATE_ALWAYS and vision.visible)
	_check("bare face: the beacon camera sees only the beacon layer",
			beacon_camera.cull_mask == 1 << (MaskBeacon.LAYER - 1))
	_check("bare face: the beacon camera follows the game camera", camera != null
			and beacon_camera.global_transform.is_equal_approx(camera.global_transform)
			and is_equal_approx(beacon_camera.fov, camera.fov))
	_check("bare face: the Monger hums", hum.playing and beacon.seen == 1.0)

	player.rotate_y(1.0)
	await _frames(2)
	_check("turning: the beacon camera keeps up",
			beacon_camera.global_transform.is_equal_approx(camera.global_transform))

	equipment.equip(MASK, PLAYER_MASK)
	await _seconds(0.8)
	_check("mask on: no beacon render, no hum",
			render.render_target_update_mode == SubViewport.UPDATE_DISABLED and not hum.playing
			and beacon.seen == 0.0)

	print("%d failure(s)" % _failures)
	get_tree().quit(_failures)


func _check(what: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Waits in game time, frame by frame, so it holds under --fixed-fps too.
func _seconds(duration: float) -> void:
	var left := duration
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
