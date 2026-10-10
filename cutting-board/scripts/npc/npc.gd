class_name Npc
extends CharacterBody3D

## A non-player character. This script only wires the parts together and answers the
## few questions every action asks; what the NPC is like lives in its components — its
## Faction says whose side it is on, its Brain's actions say what it will do about it.
##
## Friendly and hostile are not two kinds of NPC. A villager and a bandit are this same
## scene with a different faction and differently tuned actions.

## Called for help about `target`; `answers` is how many allies answer out loud.
signal called_for_help(target: Node3D, answers: int)
## Heard `caller`'s call about `target` and will answer it.
signal answering(caller: Npc, target: Node3D)

## What the NPC starts with in each hand and in its pockets. Built into real objects on
## spawn, the same way the player's hotbar draws an item into a hand.
@export var right_hand_item: ItemData
@export var left_hand_item: ItemData
@export var starting_items: Array[ItemData] = []

## Names one is drawn from at spawn for the NPC's own name — the one over its bar and on
## its pockets. Empty keeps the Inventory's display_name.
@export var name_pool: Array[String] = []

@export_group("Random Weapon")
## Weapons one is drawn from at spawn, by weight, when right_hand_item is not set. A
## throwable pick (a rock) goes in the pockets instead, to be thrown — it is not swung.
@export var weapon_pool: Array[ItemData] = []
## How likely each weapon_pool entry is, matched by position. A missing weight counts as 1.
@export var weapon_weights: Array[float] = []
## How likely the NPC is to get nothing from the pool and fight bare-handed.
@export var bare_hands_weight := 0.0
@export_group("")

@export_group("Random Extra Items")
## Items that may go in the pockets at spawn, each rolled on its own. A full inventory skips it.
@export var extra_items: Array[ItemData] = []
## Chance (0-1) for each extra_items entry, matched by position. A missing chance counts as 0.
@export var extra_item_chances: Array[float] = []
@export_group("")

@export_group("Grudges")
## Seconds a grudge against whoever hurt this NPC lasts, counted from the latest hit.
## While it lasts the attacker is fought like an enemy, whatever its faction. It also
## ends when the attacker dies or Memory lets it go after being out of sight too long.
@export var grudge_duration := 25.0
## A same-faction NPC within this many metres that has the victim in sight takes up its
## grudge when it is hit, so allies standing by step in. 0 leaves every NPC to fight its
## own fights. A hit from one of their own side is never taken up.
@export var defend_allies_radius := 0.0
## Seen this recently counts as having the victim in sight, for defend_allies_radius.
@export var defend_sight_window := 0.6
## Hears allies fight: takes up a nearby ally's grudge (their defend_allies_radius)
## without having the victim in sight, like a sleeper woken by the noise.
@export var hears_allies := false
@export_group("")

@export_group("Call For Help")
## Metres an alarm call carries to allies of this NPC's faction — the one its worn mask
## says. Each wall between them halves it.
@export var call_for_help_radius := 14.0
## How many of the allies that hear a call answer it out loud, nearest first. The rest
## come without a word.
@export var max_answers := 3
## Seconds before this NPC can call for help again.
@export var call_cooldown := 12.0
@export_group("")

@export_group("Giving Up")
## Seconds an enemy it gave up chasing (give_up_on) is left alone: not seen, not watched,
## so the NPC walks home instead of turning straight back. A blow from it ends this early.
@export var give_up_cooldown := 15.0
@export_group("")

@export_group("Sounds")
## Grunts from behind the mask when hit, and the last one when killed.
@export var hurt_sound: SoundBank = preload("res://resources/audio/npc_hurt.tres")
## Seconds between a blow landing and the grunt it gets out of the NPC.
@export var hurt_sound_delay := 0.07
@export var death_sound: SoundBank = preload("res://resources/audio/npc_death.tres")
## The body hitting the ground, this many seconds after the killing blow.
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
## Puts the weapon away at the hip out of combat. Not every NPC has one.
@onready var holster: Holster = get_node_or_null(^"%Holster")
## Poses the swing's arm motion. Optional: a body without one still strikes on time.
@onready var body_animator: BodyAnimator = get_node_or_null(^"%BodyAnimator")
## Watches an enemy before calling for help. Optional: without one, enemies are fought
## the moment they are seen.
@onready var alertness: Alertness = get_node_or_null(^"%Alertness")
@onready var alert_mark: AlertMark = get_node_or_null(^"%AlertMark")
@onready var dialogue: Dialogue = Dialogue.find_dialogue_in(self)

## Where the NPC was placed, which is what it wanders around.
var home := Vector3.ZERO

## Whoever this NPC holds a grudge against, and until when.
var _grudges := GrudgeBook.new()
## The blow being swung: who at, and seconds left until it lands. Negative when none is.
var _strike_target: Node3D
var _strike_left := -1.0
## Engine time (seconds) from which this NPC may call for help again.
var _call_ready_at := 0.0
## Enemies it gave up chasing -> engine time (seconds) until which they are left alone.
var _given_up := {}


func _ready() -> void:
	home = global_position
	if not name_pool.is_empty():
		inventory.display_name = name_pool.pick_random()
	sight.spotted.connect(_on_spotted)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	brain.setup(self)
	# Deferred so the item scenes are built once the level around the NPC is in place.
	_equip_loadout.call_deferred()


## The closest living enemy this NPC knows of, judged by where each was last seen, or
## null when it knows of none. An enemy is anyone of a hostile faction or anyone it holds
## a grudge against. `include_grudges` false leaves out everyone it holds a grudge
## against, enemy faction or not — the ones it is busy fighting back.
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


## Who to fight: the nearest one it holds a grudge against — whoever hurt it comes first —
## else the nearest known enemy of the most preferred faction in this NPC's priority
## list, or failing any of those, the nearest known enemy at all.
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


## Turns this NPC against `actor` for grudge_duration seconds from now, refreshing a
## grudge it already holds. Also notes the actor in Memory, since the fight is with
## someone it knows is there.
func hold_grudge(actor: Node3D) -> void:
	if actor == null or actor == self or not is_instance_valid(actor) or grudge_duration <= 0.0:
		return
	_grudges.hold(actor, grudge_duration)
	memory.remember(actor)


## Whether this NPC is fighting or fleeing right now, or still holds a grudge. HealthRegen
## waits for this to clear before healing.
func is_in_combat() -> bool:
	var action := brain.get_current_action()
	if action is AttackTargetAction or action is ThrowAtTargetAction or action is FleeAction:
		return true
	return not get_grudges().is_empty()


## Stops chasing `actor`: forgets it, drops any grudge against it and leaves it alone for
## give_up_cooldown seconds, so with nothing left to fight the NPC wanders back home.
func give_up_on(actor: Node3D) -> void:
	if actor == null:
		return
	memory.forget(actor)
	_grudges.drop(actor)
	_given_up[actor] = Time.get_ticks_msec() / 1000.0 + give_up_cooldown


## Whether this NPC gave up chasing `actor` a short while ago and leaves it alone.
func has_given_up_on(actor: Node3D) -> bool:
	if not _given_up.has(actor):
		return false
	if Time.get_ticks_msec() / 1000.0 < float(_given_up[actor]):
		return true
	_given_up.erase(actor)
	return false


## Told of `target` by an ally's call: knows where it really is, as if it had just seen it
## — or `spot`, where the caller last saw it, for a target no longer in the world.
func hear_of(target: Node3D, spot: Vector3) -> void:
	_given_up.erase(target)
	if is_instance_valid(target) and target.is_inside_tree():
		memory.remember(target)
	else:
		memory.remember_at(target, spot)


func has_grudge_against(actor: Node3D) -> bool:
	return get_grudges().has(actor)


## Everyone this NPC still holds a grudge against. A grudge is dropped once it has run
## out, once its target is dead or gone, and once Memory has let the target go — lost
## from sight for longer than Memory.forget_after.
func get_grudges() -> Array[Node3D]:
	return _grudges.get_held(memory)


## How keen an action should be to fight `target`: `retaliation` for someone this NPC
## holds a grudge against, if that is keener than its everyday `aggression`. 0 for no
## target. Shared by the fighting actions, so a timid villager that never starts a fight
## still answers one.
func fight_score(target: Node3D, aggression: float, retaliation: float) -> float:
	if target == null:
		return 0.0
	if has_grudge_against(target):
		return maxf(aggression, retaliation)
	return aggression


func flat_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## Swings at `target` with whatever weapon is in hand, or a bare fist. The blow does not
## land at once: the arm winds up first — a chop from above the head with a weapon, a
## shorter jab with a fist — and the damage comes on the swing's contact frame, so the
## wind-up is the tell a target can step away from. Returns false, starting nothing,
## while an earlier swing has still to land.
func strike_at(target: Node3D) -> bool:
	if is_striking() or not health.is_alive():
		return false
	# A weapon still at the hip comes out before the first blow, never after it.
	if holster:
		holster.draw_now()
	_strike_target = target
	_strike_left = swing_contact_time()
	var weapon_hand := get_weapon_hand()
	if body_animator:
		body_animator.swing(weapon_hand if weapon_hand else hand_right, weapon_hand != null)
	melee.play_swing()
	return true


## Seconds from the start of a swing to its blow landing, for what is in hand now.
func swing_contact_time() -> float:
	var armed := get_weapon_hand() != null
	if body_animator:
		return body_animator.contact_time(armed)
	return BodyAnimator.CHOP_CONTACT if armed else BodyAnimator.JAB_CONTACT


## Whether a swing is winding up and its blow has still to land.
func is_striking() -> bool:
	return _strike_left >= 0.0


## Drops the blow being wound up, so it never lands. The arm still finishes its motion.
func cancel_strike() -> void:
	_strike_target = null
	_strike_left = -1.0


func _physics_process(delta: float) -> void:
	if not is_striking():
		return
	_strike_left -= delta
	if _strike_left <= 0.0:
		var target := _strike_target
		cancel_strike()
		_land_strike(target)


## The contact frame. The eyes are turned onto the target first, since MeleeAttack
## strikes along them — without that a crouching target would be swung over. A target
## gone, dead or out of reach by now is swung at and missed.
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


## The hand holding a weapon, or null when neither does. Something held that is not a
## weapon is not swung, the same rule the player's punch follows.
func get_weapon_hand() -> HandSlot:
	for hand in hands:
		var held := hand.get_item_data()
		if held and held.is_weapon():
			return hand
	return null


## Builds an item into a real object and puts it in `hand`. Returns false when it could
## not be — no world scene, or the hand is full — and nothing is left behind.
func equip(data: ItemData, hand: HandSlot) -> bool:
	if data == null or hand == null or not hand.is_free():
		return false
	var item := data.spawn()
	if item == null:
		return false
	# HandSlot.hold reparents, which needs the item to have a parent already.
	add_child(item)
	var carryable := item.get_node_or_null("Carryable") as Carryable
	if carryable:
		carryable.take(self)
	if hand.hold(item):
		return true
	item.queue_free()
	return false


## An empty hand, or null when both are full.
func get_free_hand() -> HandSlot:
	for hand in hands:
		if hand.is_free():
			return hand
	return null


## The first item in the inventory meant for throwing, or null when there is none.
func find_throwable() -> InventoryEntry:
	for entry in inventory.get_entries():
		if entry.data and entry.data.throwable:
			return entry
	return null


## Takes an item out of the inventory and into `hand`, keeping the wear it had. The
## record is only removed once the object is really in the hand, so a failed draw loses
## nothing.
func draw(entry: InventoryEntry, hand: HandSlot) -> bool:
	if entry == null or not equip(entry.data, hand):
		return false
	Destructible.write(hand.get_held(), entry.durability)
	inventory.remove(entry)
	return true


## The reverse of draw: banks what `hand` holds back into the inventory. Returns false,
## leaving the item in the hand, when there is no room for it.
func stow(hand: HandSlot) -> bool:
	var data := hand.get_item_data()
	if data == null or not inventory.add(data, hand.get_durability()):
		return false
	hand.release().queue_free()
	return true


## Lets go of what `hand` holds, sending it off at `launch` — metres per second, world
## space. Released like the player's throw, so the item arms itself and hurts what it
## lands on.
func throw_from(hand: HandSlot, launch: Vector3) -> void:
	var thrown := _release_to_world(hand) as RigidBody3D
	if thrown == null:
		return
	# The hand sits right at the body's side, so the item is kept from colliding with
	# its own thrower until it has had a moment to clear it.
	HumanBody.keep_clear_of(thrown, self)
	thrown.linear_velocity = launch
	Sfx.play_at(throw_sound, thrown.global_position)


## Lets go of whatever each hand holds, and whatever hangs at the hips, leaving it in
## the world at rest.
func drop_held() -> void:
	for hand in hands:
		_release_to_world(hand)
	if holster:
		for hip in holster.get_slots():
			_release_to_world(hip)


## Takes what `hand` holds out of it and puts it back in the level as a loose item.
## Returns it, or null when the hand was empty.
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


## One roll per extra_items entry against its chance; returns the ones that came up.
func pick_extra_items() -> Array[ItemData]:
	return LoadoutRoll.pick_by_chance(extra_items, extra_item_chances)


## One draw from weapon_pool by weapon_weights, or null for bare hands.
func pick_random_weapon() -> ItemData:
	return LoadoutRoll.pick_weighted(weapon_pool, weapon_weights, bare_hands_weight)


## Takes up this NPC's grudge against `attacker` in the allies standing by that have it
## in sight (defend_allies_radius). Never against one of their own side.
func _rally_allies(attacker: Node3D) -> void:
	if defend_allies_radius <= 0.0 or faction.data == null:
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


## Every living NPC of this one's side — the side its worn mask says — within `radius`
## metres, nearest first. Shared by the grudge rally and the call for help.
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


## Shouts for help about `target`, last seen at `spot`. Allies of this NPC's side within
## call_for_help_radius hear it — half as far through a wall — and learn where the enemy
## really is, as if they had seen it themselves; the nearest max_answers answer out loud one after another, the rest come without a
## word. Hearing is one hop: those who hear do not call on in turn. Returns whether anyone
## answered, which the caller waits on before it attacks. Does nothing on cooldown.
func call_for_help(target: Node3D, spot: Vector3) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _call_ready_at or not health.is_alive():
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
		# Already fighting it: only where it is now is news.
		if ally.memory.knows(target) or answers >= max_answers:
			ally.hear_of(target, spot)
			continue
		var delay := 0.5 + 0.4 * answers + randf() * 0.15
		answers += 1
		ally.answer_call(self, target, spot, delay)
	called_for_help.emit(target, answers)
	return answers > 0


## Answers `caller`'s call: learns where `target` is (hear_of) and goes after it at
## once — so it does not start a watch of its own — and shouts back `delay` seconds from
## now, so several answers come one after another rather than as one chord.
func answer_call(caller: Npc, target: Node3D, spot: Vector3, delay: float) -> void:
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


## Plays one of VoiceBark's noises in this NPC's own voice.
func bark(noise: StringName) -> void:
	if dialogue and health.is_alive():
		VoiceBark.play(eyes, dialogue.voice, noise, dialogue.voice_pitch)


## Whether a wall stands between this NPC and `other`, which muffles a call.
func _wall_between(other: Npc) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
			eyes.global_position, other.eyes.global_position, sight.collision_mask)
	var exclude: Array[RID] = []
	for collider in HumanBody.colliders_of(self):
		exclude.append(collider.get_rid())
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and HumanBody.actor_of(hit.get("collider")) != other


## Hostile actors it has not yet noticed are watched first (Alertness); everyone else is
## noted in Memory at once.
func _on_spotted(actor: Node3D) -> void:
	if has_given_up_on(actor):
		return
	if alertness and alertness.wants_to_watch(actor):
		alertness.see(actor)
	else:
		memory.remember(actor)


## Being hit by someone is as good as seeing them: an NPC struck from behind turns to
## deal with whoever did it — and holds a grudge against them, so it fights back even
## against someone its faction has no quarrel with. A thrown item is credited to whoever
## threw it. A blow from a teammate (another NPC of its faction) is an accident: it still
## hurts and flinches, but brings no grudge and no rally.
##
## A hit that does not kill also lands physically: the body flinches from the force at
## the part that was struck, and the whole NPC is shoved back a little. The killing hit
## is left to _on_died, which drops the body instead.
func _on_damaged(info: DamageInfo) -> void:
	var attacker := info.get_attacker()
	if attacker and attacker != self and Faction.find_in(attacker) and not _is_teammate(attacker):
		_given_up.erase(attacker)
		memory.remember(attacker)
		if health.is_alive():
			hold_grudge(attacker)
			# Struck while still making up its mind: no more watching, a short call.
			if alertness and alertness.state == Alertness.State.WATCHING:
				alertness.raise_alarm(attacker, true)
		# A killing blow too: allies who watch one of their own die step in all the more.
		_rally_allies(attacker)
	# Before the body can fall: a mask the killing blow breaks does not come off whole.
	body.hit_mask(info)
	if health.is_alive():
		_react_to_blow(info)


## Whether `actor` is another NPC of this NPC's own faction: its blows (a stray swing,
## a thrown or kicked prop credited to it) are accidents, taken without a grudge or a
## rally. The player is never a teammate, even wearing this faction's mask: a disguise
## does not make the player's hits harmless.
func _is_teammate(actor: Node3D) -> bool:
	if not actor is Npc or faction.data == null:
		return false
	var theirs := Faction.find_in(actor)
	return theirs != null and theirs.data == faction.data


## Takes a kick from the player's Kick: hurts like any blow when it carries damage (a
## kick from an empty stamina pool does not, but still shoves), then staggers for as
## long as the kicked part decides — a trip at the legs, a push back at the body.
func kicked(info: DamageInfo, stagger_seconds: float, grip: float) -> void:
	if not health.is_alive():
		return
	if info.amount > 0:
		health.apply_damage(info)
	else:
		_react_to_blow(info)
	if health.is_alive():
		locomotion.stagger_for(stagger_seconds, grip)


## Flinch, grunt and stagger: how a living NPC takes a blow, hurt or not.
func _react_to_blow(info: DamageInfo) -> void:
	# A beat after the blow rather than on top of it: the grunt is a reaction, and
	# it keeps the two from stacking into one loud thump.
	get_tree().create_timer(hurt_sound_delay).timeout.connect(
		func() -> void:
			if is_instance_valid(eyes) and health.is_alive():
				Sfx.play_at(hurt_sound, eyes.global_position)
	)
	body.flinch(info)
	# A blow staggers: a swing still winding up is knocked out of it.
	cancel_strike()
	locomotion.push(body.get_knockback(info))


## Dead is for good: the NPC stops thinking, seeing and moving, lets go of what it held
## and goes limp, falling the way the killing blow and its own momentum send it. The
## body stays, with its inventory, for the player to search — the interaction ray finds
## it by its limbs, so the standing capsule is switched off rather than left upright
## where the NPC used to be.
func _on_died(info: DamageInfo) -> void:
	cancel_strike()
	brain.shut_down()
	locomotion.stop()
	locomotion.set_physics_process(false)
	sight.set_physics_process(false)
	# Killed while watching: the call never comes.
	if alertness:
		alertness.calm()
		alertness.set_physics_process(false)
	# Out of the actor group, so nobody keeps fighting or fleeing a corpse.
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
