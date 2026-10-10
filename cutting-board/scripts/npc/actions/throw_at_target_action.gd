class_name ThrowAtTargetAction
extends NpcAction

@export_range(0.0, 1.0) var eagerness := 0.95
@export_range(0.0, 1.0) var retaliation := 0.88
@export var min_range := 1.0
@export var max_range := 14.0
@export var throw_speed := 12.0
@export var windup := 0.6
@export var cooldown := 0.8
@export var inaccuracy_degrees := 3.0
@export var in_sight_window := 0.5

var _hand: HandSlot
var _timer := 0.0


func score(npc: Npc) -> float:
	var target := npc.get_attack_target()
	var keenness := npc.fight_score(target, eagerness, retaliation)
	if keenness <= 0.0 or npc.memory.seconds_since_seen(target) > in_sight_window:
		return 0.0
	var distance := npc.flat_distance_to(target.global_position)
	if distance < min_range or distance > max_range:
		return 0.0
	if _is_holding_item():
		return keenness
	if npc.find_throwable() == null or npc.get_free_hand() == null:
		return 0.0
	return keenness


func enter(npc: Npc) -> void:
	npc.locomotion.stop()
	_hand = null
	_timer = 0.0


func exit(npc: Npc) -> void:
	npc.locomotion.clear_facing()
	if _is_holding_item() and not npc.stow(_hand):
		npc.throw_from(_hand, Vector3.ZERO)
	_hand = null


func tick(npc: Npc, delta: float) -> void:
	var target := npc.get_attack_target()
	if target == null:
		return
	var aim := target.global_position + Vector3.UP * npc.sight.target_height
	npc.locomotion.face(aim)

	_timer -= delta
	if _timer > 0.0:
		return

	if not _is_holding_item():
		_hand = npc.get_free_hand()
		if _hand == null or not npc.draw(npc.find_throwable(), _hand):
			_hand = null
			return
		_timer = windup
		return

	npc.throw_from(_hand, _launch_velocity(_hand.global_position, aim))
	_hand = null
	_timer = cooldown


func _is_holding_item() -> bool:
	return _hand != null and not _hand.is_free()


func _launch_velocity(from: Vector3, to: Vector3) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var distance := flat.length()
	if distance < 0.01:
		return (to - from).normalized() * throw_speed
	var direction := flat / distance
	var height := to.y - from.y
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var v2 := throw_speed * throw_speed

	var angle := PI * 0.25
	var discriminant := v2 * v2 - gravity * (gravity * distance * distance + 2.0 * height * v2)
	if discriminant >= 0.0:
		angle = atan((v2 - sqrt(discriminant)) / (gravity * distance))

	var launch := (direction * cos(angle) + Vector3.UP * sin(angle)) * throw_speed
	var spread := deg_to_rad(inaccuracy_degrees)
	var side := direction.cross(Vector3.UP).normalized()
	launch = launch.rotated(Vector3.UP, randf_range(-spread, spread))
	return launch.rotated(side, randf_range(-spread, spread))
