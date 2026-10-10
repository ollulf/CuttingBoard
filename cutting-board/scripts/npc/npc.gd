class_name Npc
extends CharacterBody3D

signal called_for_help(target: Node3D, answers: int)
signal answering(caller: Npc, target: Node3D)

@export var right_hand_item: ItemData
@export var left_hand_item: ItemData
@export var starting_items: Array[ItemData] = []

@export var name_pool: Array[String] = []

@export_group("Random Weapon")
@export var weapon_pool: Array[ItemData] = []
@export var weapon_weights: Array[float] = []
@export var bare_hands_weight := 0.0
@export_group("")

@export_group("Random Extra Items")
@export var extra_items: Array[ItemData] = []
@export var extra_item_chances: Array[float] = []
@export_group("")

@export_group("Grudges")
@export var grudge_duration := 25.0
@export var defend_allies_radius := 0.0
@export var defend_sight_window := 0.6
@export var hears_allies := false
@export_group("")

@export_group("Call For Help")
@export var call_for_help_radius := 14.0
@export var max_answers := 3
@export var call_cooldown := 12.0
@export_group("")

@export_group("Corpse")
@export var corpse_settle_time := 1.5
@export_group("")

@export_group("Giving Up")
@export var give_up_cooldown := 15.0
@export_group("")

@export_group("Sounds")
@export var hurt_sound: SoundBank = preload("res://resources/audio/npc_hurt.tres")
@export var hurt_sound_delay := 0.07
@export var death_sound: SoundBank = preload("res://resources/audio/npc_death.tres")
@export var body_fall_sound: SoundBank = preload("res://resources/audio/body_fall.tres")
@export var body_fall_delay := 0.55
@export var throw_sound: SoundBank = preload("res://resources/audio/throw.tres")
@export_group("")

@onready var locomotion: Locomotion = %Locomotion
@onready var memory: Memory = %Memory
@onready var faction: Faction = %Faction
@onready var health: Health = %Health
@onready var brain: Brain = %Brain
@onready var sight: Sight = %Sight
@onready var melee: MeleeAttack = %MeleeAttack
@onready var eyes: Node3D = %Eyes
@onready var visual: Node3D = %Visual
@onready var body: NpcBody = %Body
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var hand_left: HandSlot = %HandSlotLeft
@onready var hand_right: HandSlot = %HandSlotRight
@onready var inventory: Inventory = %Inventory
@onready var hands: Array[HandSlot] = [hand_right, hand_left]
@onready var holster: Holster = get_node_or_null(^"%Holster")
@onready var body_animator: BodyAnimator = get_node_or_null(^"%BodyAnimator")
@onready var alertness: Alertness = get_node_or_null(^"%Alertness")
@onready var alert_mark: AlertMark = get_node_or_null(^"%AlertMark")
@onready var dialogue: Dialogue = Dialogue.find_dialogue_in(self)

var home := Vector3.ZERO
var blind := false

var _grudges := GrudgeBook.new()
var _strike_target: Node3D
var _strike_left := -1.0
var _call_ready_at := 0.0
var _given_up := {}
var _collapse: BlindCollapse


func _ready() -> void:
	home = global_position
	if not name_pool.is_empty():
		inventory.display_name = name_pool.pick_random()
	sight.spotted.connect(_on_spotted)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if body.has_signal(&"mask_broken"):
		body.connect(&"mask_broken", go_blind)
	brain.setup(self)
	_equip_loadout.call_deferred()


func nearest_hostile(include_grudges := true) -> Node3D:
	var grudges := get_grudges()
	var nearest: Node3D = null
	var nearest_distance := INF
	for actor in memory.get_known():
		if not Health.is_node_alive(actor):
			continue
		var grudge := grudges.has(actor)
		if grudge and not include_grudges:
			continue
		if not grudge and not faction.is_hostile_to(actor):
			continue
		var distance := flat_distance_to(memory.last_seen_position(actor))
		if distance < nearest_distance:
			nearest = actor
			nearest_distance = distance
	return nearest


func get_attack_target() -> Node3D:
	var grudge_target: Node3D = null
	var grudge_distance := INF
	for actor in get_grudges():
		var distance := flat_distance_to(memory.last_seen_position(actor))
		if distance < grudge_distance:
			grudge_target = actor
			grudge_distance = distance
	if grudge_target:
		return grudge_target

	var priorities: Array[StringName] = []
	if faction.data:
		priorities = faction.data.priority_targets
	var best: Node3D = null
	var best_rank := priorities.size()
	var best_distance := INF
	for actor in memory.get_known():
		if not faction.is_hostile_to(actor) or not Health.is_node_alive(actor):
			continue
		var theirs := Faction.find_in(actor)
		var rank := priorities.find(theirs.data.id) if theirs.data else -1
		if rank < 0:
			rank = priorities.size()
		var distance := flat_distance_to(memory.last_seen_position(actor))
		if rank < best_rank or (rank == best_rank and distance < best_distance):
			best = actor
			best_rank = rank
			best_distance = distance
	return best


func go_blind() -> void:
	if blind or not health.is_alive():
		return
	blind = true
	cancel_strike()
	faction.data = null
	faction.own_data = null
	sight.set_physics_process(false)
	memory.clear()
	_grudges.clear()
	_given_up.clear()
	if alertness:
		alertness.calm()
		alertness.set_physics_process(false)
	brain.shut_down()
	locomotion.stop()
	locomotion.clear_facing()
	for hand in hands:
		_release_to_world(hand)
	if body_animator:
		_collapse = body_animator.play_blind_collapse()
	else:
		_die_blind()


func is_collapsing() -> bool:
	return _collapse != null


func _update_collapse() -> void:
	if not health.is_alive():
		_collapse = null
		locomotion.creep = Vector3.ZERO
		return
	var forward := -visual.global_basis.z
	forward.y = 0.0
	locomotion.creep = forward.normalized() * _collapse.step_speed()
	if _collapse.is_down():
		_collapse = null
		locomotion.creep = Vector3.ZERO
		_die_blind()


func _die_blind(cause: DamageInfo = null) -> void:
	if not health.is_alive():
		return
	var info := DamageInfo.new(maxi(health.get_current(), 1))
	info.silent = true
	if cause:
		info.position = cause.position
		info.direction = cause.direction
		info.knockback = cause.knockback
	health.apply_damage(info)


func hold_grudge(actor: Node3D) -> void:
	if blind or actor == null or actor == self or not is_instance_valid(actor) or grudge_duration <= 0.0:
		return
	if Cheats.hides_from_enemies(actor):
		return
	_grudges.hold(actor, grudge_duration)
	memory.remember(actor)


func is_in_combat() -> bool:
	var action := brain.get_current_action()
	if action is AttackTargetAction or action is ThrowAtTargetAction or action is FleeAction:
		return true
	return not get_grudges().is_empty()


func give_up_on(actor: Node3D) -> void:
	if actor == null:
		return
	memory.forget(actor)
	_grudges.drop(actor)
	_given_up[actor] = Time.get_ticks_msec() / 1000.0 + give_up_cooldown


func forget_target(actor: Node3D) -> void:
	if actor == null:
		return
	if _strike_target == actor:
		cancel_strike()
	if alertness and alertness.target == actor:
		alertness.calm()
	give_up_on(actor)


func has_given_up_on(actor: Node3D) -> bool:
	if not _given_up.has(actor):
		return false
	if Time.get_ticks_msec() / 1000.0 < float(_given_up[actor]):
		return true
	_given_up.erase(actor)
	return false


func hear_of(target: Node3D, spot: Vector3) -> void:
	if blind:
		return
	_given_up.erase(target)
	if is_instance_valid(target) and target.is_inside_tree():
		memory.remember(target)
	else:
		memory.remember_at(target, spot)


func has_grudge_against(actor: Node3D) -> bool:
	return get_grudges().has(actor)


func get_grudges() -> Array[Node3D]:
	var held := _grudges.get_held(memory)
	if Cheats.no_aggro:
		for actor in held.duplicate():
			if Cheats.hides_from_enemies(actor):
				held.erase(actor)
	return held


func fight_score(target: Node3D, aggression: float, retaliation: float) -> float:
	if target == null:
		return 0.0
	if has_grudge_against(target):
		return maxf(aggression, retaliation)
	return aggression


func flat_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func strike_at(target: Node3D) -> bool:
	if blind or is_striking() or not health.is_alive():
		return false
	if holster:
		holster.draw_now()
	_strike_target = target
	_strike_left = swing_contact_time()
	var weapon_hand := get_weapon_hand()
	if body_animator:
		body_animator.swing(weapon_hand if weapon_hand else hand_right, weapon_hand != null)
	melee.play_swing()
	return true


func swing_contact_time() -> float:
	var armed := get_weapon_hand() != null
	if body_animator:
		return body_animator.contact_time(armed)
	return BodyAnimator.CHOP_CONTACT if armed else BodyAnimator.JAB_CONTACT


func is_striking() -> bool:
	return _strike_left >= 0.0


func cancel_strike() -> void:
	_strike_target = null
	_strike_left = -1.0


func _physics_process(delta: float) -> void:
	if _collapse:
		_update_collapse()
	if not is_striking():
		return
	_strike_left -= delta
	if _strike_left <= 0.0:
		var target := _strike_target
		cancel_strike()
		_land_strike(target)


func _land_strike(target: Node3D) -> void:
	if not health.is_alive() or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var target_health := Health.find_in(target)
	if target_health and not target_health.is_alive():
		return
	if flat_distance_to(target.global_position) > melee.reach:
		return
	var aim_point := target.global_position + Vector3.UP * sight.target_height
	if not eyes.global_position.is_equal_approx(aim_point):
		eyes.look_at(aim_point)
	melee.strike(get_weapon_hand())


func get_weapon_hand() -> HandSlot:
	for hand in hands:
		var held := hand.get_item_data()
		if held and held.is_weapon():
			return hand
	return null


func equip(data: ItemData, hand: HandSlot) -> bool:
	if data == null or hand == null or not hand.is_free():
		return false
	var item := data.spawn()
	if item == null:
		return false
	add_child(item)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.take(self)
	if hand.hold(item):
		return true
	item.queue_free()
	return false


func get_free_hand() -> HandSlot:
	for hand in hands:
		if hand.is_free():
			return hand
	return null


func find_throwable() -> InventoryEntry:
	for entry in inventory.get_entries():
		if entry.data and entry.data.throwable:
			return entry
	return null


func draw(entry: InventoryEntry, hand: HandSlot) -> bool:
	if entry == null or not equip(entry.data, hand):
		return false
	Destructible.write(hand.get_held(), entry.durability)
	inventory.remove(entry)
	return true


func stow(hand: HandSlot) -> bool:
	var data := hand.get_item_data()
	if data == null or not inventory.add(data, hand.get_durability()):
		return false
	hand.release().queue_free()
	return true


func throw_from(hand: HandSlot, launch: Vector3) -> void:
	var thrown := _release_to_world(hand) as RigidBody3D
	if thrown == null:
		return
	HumanBody.keep_clear_of(thrown, self)
	thrown.linear_velocity = launch
	Sfx.play_at(throw_sound, thrown.global_position)


func drop_held() -> void:
	for hand in hands:
		_release_to_world(hand)
	if holster:
		for hip in holster.get_slots():
			_release_to_world(hip)


func _release_to_world(hand: HandSlot) -> Node3D:
	var item := hand.release()
	if item == null:
		return null
	item.reparent(get_parent(), true)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.return_to_world()
	return item


func _equip_loadout() -> void:
	var right := right_hand_item if right_hand_item else pick_random_weapon()
	if right and right.throwable:
		inventory.add(right)
	else:
		equip(right, hand_right)
	equip(left_hand_item, hand_left)
	for data in starting_items:
		inventory.add(data)
	for data in pick_extra_items():
		inventory.add(data)


func pick_extra_items() -> Array[ItemData]:
	return LoadoutRoll.pick_by_chance(extra_items, extra_item_chances)


func pick_random_weapon() -> ItemData:
	return LoadoutRoll.pick_weighted(weapon_pool, weapon_weights, bare_hands_weight)


func _rally_allies(attacker: Node3D) -> void:
	if blind or defend_allies_radius <= 0.0 or faction.data == null:
		return
	var theirs := Faction.find_in(attacker)
	if theirs and theirs.data == faction.data:
		return
	for ally in allies_within(defend_allies_radius):
		if ally == attacker:
			continue
		if not ally.hears_allies and ally.memory.seconds_since_seen(self) > defend_sight_window:
			continue
		ally.hold_grudge(attacker)


func allies_within(radius: float) -> Array[Npc]:
	var allies: Array[Npc] = []
	if faction.data == null or radius <= 0.0:
		return allies
	for node in get_tree().get_nodes_in_group(Faction.GROUP):
		var ally := node as Npc
		if (ally == null or ally == self or not ally.health.is_alive()
				or ally.faction.data != faction.data):
			continue
		if global_position.distance_to(ally.global_position) <= radius:
			allies.append(ally)
	allies.sort_custom(func(a: Npc, b: Npc) -> bool:
		return global_position.distance_squared_to(a.global_position) \
				< global_position.distance_squared_to(b.global_position))
	return allies


func call_for_help(target: Node3D, spot: Vector3) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if blind or now < _call_ready_at or not health.is_alive():
		return false
	_call_ready_at = now + call_cooldown
	bark(&"call")
	var answers := 0
	for ally in allies_within(call_for_help_radius):
		var reach := call_for_help_radius * (0.5 if _wall_between(ally) else 1.0)
		if global_position.distance_to(ally.global_position) > reach:
			continue
		if ally.alertness:
			ally.alertness.calm()
		if ally.memory.knows(target) or answers >= max_answers:
			ally.hear_of(target, spot)
			continue
		var delay := 0.5 + 0.4 * answers + randf() * 0.15
		answers += 1
		ally.answer_call(self, target, spot, delay)
	called_for_help.emit(target, answers)
	return answers > 0


func answer_call(caller: Npc, target: Node3D, spot: Vector3, delay: float) -> void:
	if blind:
		return
	hear_of(target, spot)
	answering.emit(caller, target)
	get_tree().create_timer(delay, true, true).timeout.connect(
		func() -> void:
			if not health.is_alive():
				return
			bark(&"answer")
			if alert_mark:
				alert_mark.flash()
	)


func bark(noise: StringName) -> void:
	if dialogue and health.is_alive():
		VoiceBark.play(eyes, dialogue.voice, noise, dialogue.voice_pitch)


func _wall_between(other: Npc) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
			eyes.global_position, other.eyes.global_position, sight.collision_mask)
	var exclude: Array[RID] = []
	for collider in HumanBody.colliders_of(self):
		exclude.append(collider.get_rid())
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and HumanBody.actor_of(hit.get("collider")) != other


func _on_spotted(actor: Node3D) -> void:
	if blind or has_given_up_on(actor):
		return
	if alertness and alertness.wants_to_watch(actor):
		alertness.see(actor)
	else:
		memory.remember(actor)


func _on_damaged(info: DamageInfo) -> void:
	var attacker := info.get_attacker()
	if not blind and attacker and attacker != self and Faction.find_in(attacker) and not _is_teammate(attacker):
		_given_up.erase(attacker)
		memory.remember(attacker)
		if health.is_alive():
			hold_grudge(attacker)
			if alertness and alertness.state == Alertness.State.WATCHING:
				alertness.raise_alarm(attacker, true)
		_rally_allies(attacker)
	var collapsing := _collapse != null
	body.hit_mask(info)
	if collapsing and health.is_alive():
		_collapse = null
		locomotion.creep = Vector3.ZERO
		_die_blind.call_deferred(info)
	elif health.is_alive():
		_react_to_blow(info)


func _is_teammate(actor: Node3D) -> bool:
	if not actor is Npc or faction.data == null:
		return false
	var theirs := Faction.find_in(actor)
	return theirs != null and theirs.data == faction.data


func kicked(info: DamageInfo, stagger_seconds: float, grip: float) -> void:
	if not health.is_alive():
		return
	if info.amount > 0:
		health.apply_damage(info)
	else:
		_react_to_blow(info)
	if health.is_alive():
		locomotion.stagger_for(stagger_seconds, grip)


func _react_to_blow(info: DamageInfo) -> void:
	get_tree().create_timer(hurt_sound_delay).timeout.connect(
		func() -> void:
			if is_instance_valid(eyes) and health.is_alive():
				Sfx.play_at(hurt_sound, eyes.global_position)
	)
	body.flinch(info)
	cancel_strike()
	locomotion.push(body.get_knockback(info))


func _on_died(info: DamageInfo) -> void:
	cancel_strike()
	brain.shut_down()
	locomotion.stop()
	locomotion.set_physics_process(false)
	sight.set_physics_process(false)
	if alertness:
		alertness.calm()
		alertness.set_physics_process(false)
	remove_from_group(Faction.GROUP)
	drop_held()
	collision_shape.set_deferred("disabled", true)
	body.go_limp(info, velocity)
	velocity = Vector3.ZERO
	Sfx.play_at(death_sound, eyes.global_position)
	get_tree().create_timer(body_fall_delay).timeout.connect(
		func() -> void:
			if is_instance_valid(body):
				Sfx.play_at(body_fall_sound, body.get_center())
	)
	get_tree().create_timer(corpse_settle_time, false).timeout.connect(_watch_corpse)


func _watch_corpse() -> void:
	inventory.changed.connect(_break_up_if_looted)
	inventory.viewers_changed.connect(_break_up_if_looted)
	_break_up_if_looted()


func _break_up_if_looted() -> void:
	if not inventory.is_empty() or inventory.is_viewed():
		return
	inventory.changed.disconnect(_break_up_if_looted)
	inventory.viewers_changed.disconnect(_break_up_if_looted)
	body.fell_apart.connect(queue_free)
	if not body.fall_apart():
		body.fell_apart.disconnect(queue_free)
