extends RigidBody3D

@export var heal_amount := 30
@export var heal_time := 0.0
@export_range(1, 10) var heal_steps := 1
@export var open_sound: SoundBank = preload("res://resources/audio/monger_cork.tres")
@export var use_sound: SoundBank = preload("res://resources/audio/glue.tres")
@export var clamp_sound: SoundBank = preload("res://resources/audio/impact_wood.tres")
@export var knock_sound: SoundBank = preload("res://resources/audio/glue_knock.tres")

@onready var _usable: Usable = %Usable


func _ready() -> void:
	_usable.can_use = _can_mend
	_usable.used.connect(_on_used)
	_usable.use_beat.connect(_on_use_beat)
	_usable.wasted.connect(_on_wasted.unbind(1))


func _can_mend(by: Node) -> bool:
	var health := Health.find_in(by)
	return health != null and health.is_alive() and health.get_current() < health.max_health


func _on_used(by: Node) -> void:
	mend(Health.find_in(by), heal_amount, heal_time, heal_steps)
	_on_wasted()


func _on_use_beat(beat_name: StringName, _by: Node) -> void:
	match beat_name:
		&"open":
			Sfx.play(open_sound, -4.0)
		&"dab":
			Sfx.play(use_sound)
		&"clamp":
			Sfx.play(clamp_sound, -4.0)
		&"knock":
			Sfx.play(knock_sound)


func _on_wasted() -> void:
	if _usable.uses_remaining == 0:
		queue_free()


static func mend(health: Health, amount: int, seconds: float, steps: int) -> void:
	if health == null or amount <= 0:
		return
	steps = maxi(steps, 1)
	if steps == 1:
		health.heal(amount)
		return
	var tween := health.create_tween()
	var given := 0
	for step in steps:
		if step > 0:
			tween.tween_interval(seconds / maxf(steps - 1, 1))
		var share := roundi(float(amount) * (step + 1) / steps) - given
		given += share
		tween.tween_callback(health.heal.bind(share))
