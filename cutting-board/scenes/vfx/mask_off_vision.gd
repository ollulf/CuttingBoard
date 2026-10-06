class_name MaskOffVision
extends CanvasLayer

## What the player sees with no mask on: the world goes black and dark wood grain flows
## through it (mask_off_vision.gdshader, concept A of docs/concepts/mask-off-vision.md).
## It follows the Mask slot of `equipment`: taking the mask off in the inventory, or
## having it broken off the face, fades the grain in; putting one on fades it out.
##
## Like FunhouseMirror this layer sits above PsxScreen's display and below the HUD, so it
## covers only the world and the inventory and HUD stay on top. The player can still
## walk about blind. While the game is paused it hides, so the pause menu's own mask,
## which is drawn in the world, can still be read.

## Whose Mask slot to follow.
@export var equipment: Equipment
## Seconds the fade takes, in and out.
@export var fade_time := 0.6

@onready var _view: ColorRect = %View

## 0 while a mask is worn, 1 while the face is bare.
var amount := 0.0
var _target := 0.0
var _time := 0.0


func _ready() -> void:
	if equipment != null:
		equipment.changed.connect(_on_equipment_changed)
		_on_equipment_changed()
		amount = _target
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		hide()
	elif what == NOTIFICATION_UNPAUSED:
		_apply()


func _process(delta: float) -> void:
	_time += delta
	amount = move_toward(amount, _target, delta / maxf(fade_time, 0.001))
	_apply()


func _on_equipment_changed() -> void:
	_target = 1.0 if equipment.is_free(Equipment.Slot.MASK) else 0.0
	set_process(amount != _target or _target > 0.0)


func _apply() -> void:
	visible = amount > 0.0
	# Keeps running while bare-faced so the grain flows; stops once the world is back.
	set_process(amount != _target or _target > 0.0)
	var material := _view.material as ShaderMaterial
	material.set_shader_parameter("fade", amount)
	material.set_shader_parameter("time", _time)
