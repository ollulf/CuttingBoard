extends RigidBody3D

## Wood glue. Everyone in the village is made of wood, so a dab of it mends: used from
## the hand (a plain click), it heals whoever holds it, spread over a moment as the glue
## takes, and the pot is gone once its last dab is spent. Nobody unhurt can use it, so a
## click at full health wastes nothing.
##
## Which pot, skin or stick it looks like is only the Mesh node's mesh: the concepts are
## assets/meshes/props/wood_glue_a|b|c.res, built by scripts/import/build_wood_glue.gd.

## Health given back by one dab, all told.
@export var heal_amount := 30
## Seconds the heal is spread over, in heal_steps equal parts: the first lands at once,
## the last at the end. 0 heals it all at once.
@export var heal_time := 0.6
@export_range(1, 10) var heal_steps := 3
@export var use_sound: SoundBank = preload("res://resources/audio/glue.tres")

@onready var _usable: Usable = %Usable


func _ready() -> void:
	_usable.can_use = _can_mend
	_usable.used.connect(_on_used)


func _can_mend(by: Node) -> bool:
	var health := Health.find_in(by)
	return health != null and health.is_alive() and health.get_current() < health.max_health


func _on_used(by: Node) -> void:
	mend(Health.find_in(by), heal_amount, heal_time, heal_steps)
	Sfx.play_at(use_sound, global_position)
	if _usable.uses_remaining == 0:
		queue_free()


## Heals `amount` in `steps` parts over `seconds`. The steps run on a tween of the Health
## itself, so they carry on after the glue that started them is gone.
static func mend(health: Health, amount: int, seconds: float, steps: int) -> void:
	if health == null or amount <= 0:
		return
	steps = maxi(steps, 1)
	var tween := health.create_tween()
	var given := 0
	for step in steps:
		if step > 0:
			tween.tween_interval(seconds / maxf(steps - 1, 1))
		# Rounded so the parts always add up to the whole amount.
		var share := roundi(float(amount) * (step + 1) / steps) - given
		given += share
		tween.tween_callback(health.heal.bind(share))
