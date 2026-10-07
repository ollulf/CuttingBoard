extends Node3D

## First-person clip of the Churn Thumper in the village: the player holds it armed in
## the right hand with spikes in the bag, fires at a training dummy (recoil, spike
## sticking in it), then clicks again to rearm (rearm_thumper_both).
##
##   godot --path cutting-board --position -10000,-10000 --write-movie <out>.avi \
##       --fixed-fps 30 --resolution 960x540 --quit-after 120 res://tests/visual/thumper_capture.tscn

const VILLAGE := preload("res://scenes/levels/village.tscn")
const TERRAIN := preload("res://scenes/levels/valley_terrain.tscn")
const LIGHTING := preload("res://scenes/levels/lighting/tallow_fair_lighting.tscn")
const PLAYER := preload("res://scenes/characters/player.tscn")
const DUMMY := preload("res://scenes/characters/training_dummy.tscn")
const THUMPER := preload("res://resources/items/churn_thumper.tres")
const SPIKE := preload("res://resources/items/railroad_spike.tres")

const FEET := Vector3(1.4, 0.0, 2.8)
const FACING := Vector3(2.6, 0.0, 8.4)

var _player: Node3D
var _thumper: Node3D
var _dummy: Node3D


func _ready() -> void:
	add_child(LIGHTING.instantiate())
	add_child(TERRAIN.instantiate())
	add_child(VILLAGE.instantiate())
	_player = PLAYER.instantiate()
	add_child(_player)
	_player.global_position = FEET + Vector3.UP * 30.0
	var flat := (FACING - FEET).normalized()
	_player.basis = Basis.looking_at(flat, Vector3.UP)
	(_player.get_node("%Camera3D") as Camera3D).current = true
	_dummy = DUMMY.instantiate()
	add_child(_dummy)
	_dummy.global_position = FEET + flat * 5.0 + Vector3.UP * 30.0
	_dummy.basis = Basis.looking_at(-flat, Vector3.UP)
	_play.call_deferred()


func _play() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Stood on the terrain, wherever its height is here.
	_player.global_position = _ground(FEET)
	_dummy.global_position = _ground(FEET + (FACING - FEET).normalized() * 5.0)
	await get_tree().create_timer(0.1).timeout
	for i in 3:
		_player.inventory.add(SPIKE)
	_thumper = _player.interactor.spawn_into_hand(THUMPER, -1, _player.hand_right)
	_thumper.armed = true
	_thumper._sync_action()
	await get_tree().create_timer(0.8).timeout
	_click()
	await get_tree().create_timer(0.9).timeout
	_click()


func _click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	_player._use_hand(_player.hand_right, event)


func _ground(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at - Vector3.UP * 60.0)
	query.exclude = [_player.get_rid(), _dummy.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else at
