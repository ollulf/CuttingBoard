class_name AlertMark
extends Label3D

const CALM := Color(0.95, 0.9, 0.75)
const ALARM := Color(0.9, 0.12, 0.08)

@export var flash_time := 1.5

var _flash_left := 0.0

@onready var _npc: Npc = owner


func _ready() -> void:
	visible = false


func flash() -> void:
	_flash_left = flash_time


func _process(delta: float) -> void:
	var alertness := _npc.alertness
	_flash_left -= delta
	if not _npc.health.is_alive() or alertness == null:
		visible = false
		return
	match alertness.state:
		Alertness.State.WATCHING, Alertness.State.SEARCHING:
			visible = true
			text = "?"
			modulate = CALM.lerp(ALARM, alertness.meter / alertness.watch_time)
		Alertness.State.CALLING:
			visible = true
			text = "!"
			modulate = ALARM
		_:
			visible = _flash_left > 0.0
			text = "!"
			modulate = ALARM
