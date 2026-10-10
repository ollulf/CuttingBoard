class_name MaskBeacon
extends Node3D

const LAYER := 20
const GROUP := &"mask_beacons"

@export var visual: Node3D
@export var hum_volume_db := -8.0

@onready var _hum: AudioStreamPlayer3D = %Hum

var seen := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if visual == null:
		visual = get_parent() as Node3D
	tag_meshes()
	_hum.volume_db = -80.0


func tag_meshes() -> void:
	if visual == null:
		return
	for node in visual.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).set_layer_mask_value(LAYER, true)


func set_seen(amount: float) -> void:
	seen = amount
	if amount <= 0.0:
		if _hum.playing:
			_hum.stop()
		return
	if not _hum.playing:
		tag_meshes()
		_hum.play()
	_hum.volume_db = hum_volume_db + linear_to_db(maxf(amount, 0.001))
