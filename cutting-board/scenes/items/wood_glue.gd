extends RigidBody3D

## Wood glue. Everyone in the village is made of wood, so a dab of it mends: used from
## the hand (a plain click), it plays the chest-crack use (use_glue_both, 2.8 s: the view
## tilts down to a cracked plank, the pot hand dabs glue in twice, the other palm clamps
## it and holds) and heals whoever holds it all at once at the end. The pot is gone once
## its last dab is spent. Nobody unhurt can use it, so a click at full health wastes
## nothing. The player cancels the use on a hit or a move; past the first dab the glue is
## in the crack and that dab is spent all the same (Usable.waste).
##
## Which pot, skin or stick it looks like is only the Mesh node's mesh: the concepts are
## assets/meshes/props/wood_glue_a|b|c.res, built by tools/import/build_wood_glue.gd.

## Health given back by one dab, all told.
@export var heal_amount := 30
## Seconds the heal is spread over, in heal_steps equal parts: the first lands at once,
## the last at the end. 0 heals it all at once, which is how the timed use lands it.
@export var heal_time := 0.0
@export_range(1, 10) var heal_steps := 1
## The beats of the use: the lid, each dab, the clamp, the knocks of the held palm.
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


## A spent dab, healed or not: the empty pot goes.
func _on_wasted() -> void:
	if _usable.uses_remaining == 0:
		queue_free()


## Heals `amount` in `steps` parts over `seconds`. The steps run on a tween of the Health
## itself, so they carry on after the glue that started them is gone.
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
		# Rounded so the parts always add up to the whole amount.
		var share := roundi(float(amount) * (step + 1) / steps) - given
		given += share
		tween.tween_callback(health.heal.bind(share))
