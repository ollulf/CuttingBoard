class_name MaskBeacon
extends Node3D

## Marks its parent as something a bare-faced player still sees through the mask-off
## grain (concept: docs/concepts, first five minutes, round 2): the Mask-Monger shows as a
## warm glowing silhouette and his puppet hums a tune you can follow by ear.
##
## It puts every mesh under `visual` on `LAYER` as well as its own layers, so the
## main view is unchanged and MaskOffVision's beacon camera, which renders only that
## layer, sees him through everything: he is the one thing a faceless puppet can see.
## MaskOffVision calls `set_seen` with its fade amount; the hum fades with it.

## The render layer (1-based) the beacon view draws.
const LAYER := 20
const GROUP := &"mask_beacons"

## The meshes to light up; defaults to the parent.
@export var visual: Node3D
## Loudest the hum gets, in dB, once the grain is fully in.
@export var hum_volume_db := -8.0

@onready var _hum: AudioStreamPlayer3D = %Hum

## How far the grain is in (0..1), as last told by MaskOffVision.
var seen := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if visual == null:
		visual = get_parent() as Node3D
	tag_meshes()
	_hum.volume_db = -80.0


## Puts every visual instance under `visual` on the beacon layer too.
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
