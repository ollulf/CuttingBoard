class_name MaskBurnRitual
extends Usable

const TOSS := 0.8
const IGNITE := 1.5
const SPIRAL := 2.5
const BOTTLE_UP := 3.7
const SET_DOWN := 4.6
const END := 5.8

const APEX := Vector3(0.0, 2.5, -0.6)

const SOUL_SHADER := preload("res://assets/shaders/soul_swirl.gdshader")

@export var reward: ItemData = preload("res://resources/items/soul_bottle.tres")
@export var shattered_mask: ItemData = preload("res://resources/items/shattered_mask.tres")
@export var repair_sound: SoundBank = preload("res://resources/audio/monger_babble.tres")
@export var mend_sound: SoundBank = preload("res://resources/audio/monger_repair.tres")
@export var landing_distance := 0.7

@export_group("Sounds")
@export var take_sound: SoundBank = preload("res://resources/audio/monger_take.tres")
@export var toss_sound: SoundBank = preload("res://resources/audio/monger_toss.tres")
@export var ignite_sound: SoundBank = preload("res://resources/audio/monger_ignite.tres")
@export var gasp_sound: SoundBank = preload("res://resources/audio/monger_gasp.tres")
@export var soul_sound: SoundBank = preload("res://resources/audio/monger_soul.tres")
@export var cork_sound: SoundBank = preload("res://resources/audio/monger_cork.tres")
@export var lob_sound: SoundBank = preload("res://resources/audio/throw.tres")
@export var clink_sound: SoundBank = preload("res://resources/audio/monger_clink.tres")
@export var babble_sound: SoundBank = preload("res://resources/audio/monger_babble.tres")
@export_group("")

signal ritual_started(mask: ItemData)
signal ritual_finished(bottle: Node3D)
signal mask_repaired(mask: Node3D)
signal sound_cued(bank: SoundBank, at: float)

@onready var _npc: Npc = get_parent()
@onready var _model: Node3D = %Body
@onready var _puppet_arm: Node3D = _model.get_node("%PuppetArm")
@onready var _lantern_arm: Node3D = _model.get_node("%LanternArm")
@onready var _head: Node3D = _model.get_node("%Head")
@onready var _jaw: Node3D = _model.get_node("%Jaw")
@onready var _hand: Node3D = _model.get_node("%Puppet")

var _time := -1.0
var _giver: Node3D
var _mask: Node3D
var _flare_mat: StandardMaterial3D
var _fire_light: OmniLight3D
var _embers: GPUParticles3D
var _shavings: GPUParticles3D
var _smoke: GPUParticles3D
var _soul: MeshInstance3D
var _bottle: RigidBody3D
var _arm_rest: Basis
var _lantern_rest: Basis
var _mask_start := Vector3.ZERO
var _bottle_layers := Vector2i.ZERO
var _bottle_ground := Vector3.ZERO
var _cues := {}


func _ready() -> void:
	held_verb = ""
	can_use = func(by: Node) -> bool: return _can_give(by) or _can_repair(by)
	used.connect(_on_used)
	process_priority = 10
	set_process(false)


func get_prompt(by: Node) -> String:
	if _can_give(by):
		return "Give shattered mask"
	if _can_repair(by):
		return "Repair mask (1 soul)"
	return ""


func is_playing() -> bool:
	return _time >= 0.0


func _can_give(by: Node) -> bool:
	return _will_trade(by) and _find_hand_mask(by) != null


func _can_repair(by: Node) -> bool:
	return _will_trade(by) and _find_damaged_mask(by) != null and _find_payment(by) != null


func _will_trade(by: Node) -> bool:
	if is_playing() or by == null:
		return false
	var health := Health.find_in(_npc)
	if health and not health.is_alive():
		return false
	return not _npc.has_grudge_against(by as Node3D)


func _find_hand_mask(by: Node) -> HandSlot:
	for hand_name: String in ["%HandSlotRight", "%HandSlotLeft"]:
		var hand := by.get_node_or_null(hand_name) as HandSlot
		if hand and shattered_mask and hand.get_item_data() == shattered_mask:
			return hand
	return null


func _find_damaged_mask(by: Node) -> HandSlot:
	for hand_name: String in ["%HandSlotRight", "%HandSlotLeft"]:
		var hand := by.get_node_or_null(hand_name) as HandSlot
		if hand == null or not hand.get_item_data() is MaskData:
			continue
		var left := hand.get_durability()
		if left >= 0 and left < hand.get_item_data().durability:
			return hand
	return null


func _find_payment(by: Node) -> InventoryEntry:
	var inventory := by.get_node_or_null("Inventory") as Inventory
	if inventory == null:
		return null
	for entry in inventory.get_entries():
		if entry.data == reward:
			return entry
	return null


func _repair(by: Node) -> void:
	var hand := _find_damaged_mask(by)
	var payment := _find_payment(by)
	if hand == null or payment == null:
		return
	(by.get_node("Inventory") as Inventory).remove(payment)
	var mask := hand.get_held()
	Destructible.write(mask, hand.get_item_data().durability)
	Sfx.play_at(repair_sound, _head.global_position)
	Sfx.play_at(mend_sound, _hand.global_position)
	mask_repaired.emit(mask)
	get_tree().call_group(&"interaction_prompts", &"refresh")


func _on_used(by: Node) -> void:
	var hand := _find_hand_mask(by)
	if hand == null:
		_repair(by)
		return
	_time = 0.0
	var data := hand.get_item_data()
	_mask = hand.release()
	_mask.reparent(get_tree().current_scene)
	_giver = by as Node3D
	if _mask:
		_mask_start = _mask.global_position
		_freeze(_mask)
	_begin()
	ritual_started.emit(data)


func _begin() -> void:
	_time = 0.0
	_cues.clear()
	_npc.brain.set_physics_process(false)
	_npc.locomotion.stop()
	_npc.locomotion.face(_giver.global_position)
	var to_giver := _giver.global_position - _npc.global_position
	to_giver.y = 0.0
	_bottle_ground = _giver.global_position \
			- to_giver.normalized() * landing_distance + Vector3.UP * 0.15
	_build_effects()
	set_process(true)


func _finish() -> void:
	_time = -1.0
	set_process(false)
	_puppet_arm.basis = _arm_rest
	_lantern_arm.basis = _lantern_rest
	_npc.locomotion.clear_facing()
	_npc.brain.set_physics_process(true)
	for node: Node in [_mask, _fire_light, _embers, _shavings, _smoke, _soul]:
		if is_instance_valid(node):
			node.queue_free()
	var bottle := _bottle
	_bottle = null
	if is_instance_valid(bottle):
		bottle.scale = Vector3.ONE
		bottle.collision_layer = _bottle_layers.x
		bottle.collision_mask = _bottle_layers.y
		bottle.freeze = false
	ritual_finished.emit(bottle)
	get_tree().call_group(&"interaction_prompts", &"refresh")




func _build_effects() -> void:
	_arm_rest = _puppet_arm.basis
	_lantern_rest = _lantern_arm.basis
	var scene := get_tree().current_scene
	if _mask:
		var flare := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.3, 0.36)
		flare.mesh = quad
		_flare_mat = StandardMaterial3D.new()
		_flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flare_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flare_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_flare_mat.albedo_color = Color(1.0, 0.5, 0.1, 0.0)
		flare.material_override = _flare_mat
		_mask.add_child(flare)

	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.55, 0.2)
	_fire_light.omni_range = 5.0
	_fire_light.light_energy = 0.0
	scene.add_child(_fire_light)
	_embers = _make_particles(Color(1.0, 0.6, 0.15), 0.03, 60, Vector3(0, 2.0, 0), 1.0)
	_shavings = _make_particles(Color(0.75, 0.6, 0.4), 0.04, 24, Vector3(0, -6.0, 0), 1.2)
	_smoke = _make_particles(Color(0.55, 0.5, 0.6, 0.6), 0.09, 40, Vector3(0, 0.2, 0), 1.6)
	var apex := _apex()
	for p: GPUParticles3D in [_embers, _shavings, _smoke]:
		p.global_position = apex
	_fire_light.global_position = apex

	_soul = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	_soul.mesh = sphere
	var soul_mat := ShaderMaterial.new()
	soul_mat.shader = SOUL_SHADER
	_soul.material_override = soul_mat
	_soul.visible = false
	scene.add_child(_soul)
	var soul_light := OmniLight3D.new()
	soul_light.light_color = Color(1.0, 0.7, 0.3)
	soul_light.omni_range = 2.0
	soul_light.light_energy = 1.5
	_soul.add_child(soul_light)

	_bottle = reward.spawn() as RigidBody3D
	if _bottle:
		_bottle.freeze = true
		_bottle_layers = Vector2i(_bottle.collision_layer, _bottle.collision_mask)
		_bottle.collision_layer = 0
		_bottle.collision_mask = 0
		_bottle.visible = false
		scene.add_child(_bottle)


func _make_particles(color: Color, size: float, amount: int, gravity: Vector3,
		lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.draw_pass_1 = mesh
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.6
	process.gravity = gravity
	process.scale_min = 0.5
	process.scale_max = 1.2
	p.process_material = process
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = false
	get_tree().current_scene.add_child(p)
	return p


func _apex() -> Vector3:
	return _npc.to_global(APEX)


func _process(delta: float) -> void:
	_time += delta
	var t := _time
	var hand := _hand.global_position
	var apex := _apex()

	var reach := _bump(t, 0.0, TOSS) * 0.6 + _bump(t, TOSS, IGNITE) * 1.3 \
			+ _bump(t, BOTTLE_UP - 0.2, SET_DOWN + 0.5) * 1.0
	_puppet_arm.basis = _puppet_arm.basis * Basis(Vector3.RIGHT, reach)
	_lantern_arm.basis = _lantern_rest * Basis(Vector3.RIGHT,
			_bump(t, TOSS + 0.2, SPIRAL + 0.3) * 1.4)
	_head.basis = _head.basis * Basis(Vector3.RIGHT, _bump(t, TOSS, SPIRAL + 0.8) * 0.5)
	var jaw := 0.0
	if t > IGNITE and t < IGNITE + 0.6:
		jaw = 0.6
	elif t > SPIRAL and t < BOTTLE_UP + 0.6:
		jaw = 0.25 + 0.25 * sin(t * 40.0)
	elif t > SET_DOWN + 0.3 and t < END - 0.3:
		jaw = 0.2 + 0.2 * sin(t * 25.0)
	_jaw.basis = _jaw.basis * Basis(Vector3.RIGHT, jaw)

	if is_instance_valid(_mask):
		if t < TOSS:
			var k := smoothstep(0.0, TOSS, t)
			_mask.global_position = _mask_start.lerp(hand + Vector3(0, 0.15, 0), k)
		elif t < IGNITE + 0.9:
			var k := clampf((t - TOSS) / (IGNITE - TOSS), 0.0, 1.0)
			var from := hand + Vector3(0, 0.15, 0)
			_mask.global_position = from.lerp(apex, 1.0 - pow(1.0 - k, 2.0)) \
					+ Vector3(0, sin(t * 3.0) * 0.03, 0)
			_mask.rotation = Vector3(0, _npc.rotation.y, (t - TOSS) * 5.0 * (1.0 - k * 0.8))
		var burn := clampf((t - IGNITE) / 0.9, 0.0, 1.0)
		_mask.visible = t < IGNITE + 0.9
		_mask.scale = Vector3.ONE * maxf(0.01,
				(1.0 + burn * 0.25) * (1.0 - smoothstep(0.6, 1.0, burn)))
		if _flare_mat:
			_flare_mat.albedo_color.a = _bump(t, IGNITE - 0.05, IGNITE + 0.9) * 1.2
	_fire_light.light_energy = _bump(t, IGNITE - 0.1, SPIRAL + 0.2) * 4.0
	_embers.emitting = t > IGNITE and t < IGNITE + 0.8
	_shavings.emitting = t > IGNITE and t < IGNITE + 0.3
	_smoke.emitting = t > IGNITE + 0.4 and t < SPIRAL + 0.6

	var vial_mouth := hand + Vector3(0, 0.35, 0)
	_soul.visible = t > SPIRAL - 0.2 and t < BOTTLE_UP + 0.5
	if _soul.visible:
		var k := clampf((t - (SPIRAL - 0.2)) / (BOTTLE_UP + 0.5 - (SPIRAL - 0.2)), 0.0, 1.0)
		var radius := 0.5 * (1.0 - k)
		var angle := k * TAU * 2.5
		_soul.global_position = apex.lerp(vial_mouth, k * k * (3.0 - 2.0 * k)) \
				+ Vector3(cos(angle), 0, sin(angle)) * radius
		_soul.scale = Vector3.ONE * (1.0 - k * 0.6) * (1.0 + 0.15 * sin(t * 20.0))

	if _bottle:
		_bottle.visible = t > BOTTLE_UP
		if t > BOTTLE_UP and t < SET_DOWN:
			_bottle.global_position = hand + Vector3(0, 0.2, 0)
			var pop := _bump(t, BOTTLE_UP + 0.75, BOTTLE_UP + 0.9)
			_bottle.scale = Vector3(1.0 + pop * 0.2, 1.0 - pop * 0.2, 1.0 + pop * 0.2) \
					* maxf(0.01, minf(1.0, (t - BOTTLE_UP) / 0.15))
		elif t >= SET_DOWN:
			var k := clampf((t - SET_DOWN) / 0.6, 0.0, 1.0)
			var from := hand + Vector3(0, 0.2, 0)
			_bottle.global_position = from.lerp(_bottle_ground, k) \
					+ Vector3(0, sin(k * PI) * 0.6, 0)
			_bottle.scale = Vector3.ONE
			_bottle.rotation.z = (1.0 - k) * 0.6

	_cue(0.0, take_sound, hand)
	_cue(TOSS, toss_sound, hand)
	_cue(IGNITE, ignite_sound, apex)
	_cue(IGNITE + 0.05, gasp_sound, hand)
	_cue(SPIRAL - 0.2, soul_sound, apex)
	_cue(BOTTLE_UP + 0.8, cork_sound, hand)
	_cue(SET_DOWN, lob_sound, hand)
	_cue(SET_DOWN + 0.3, babble_sound, hand)
	_cue(SET_DOWN + 0.6, clink_sound, _bottle_ground)

	if t > END:
		_finish()


func _cue(at: float, bank: SoundBank, where: Vector3) -> void:
	if _time >= at and not _cues.has(at):
		_cues[at] = true
		Sfx.play_at(bank, where)
		sound_cued.emit(bank, at)


func _freeze(node: Node3D) -> void:
	var body := node as RigidBody3D
	if body:
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
	var carryable := node.get_node_or_null("Carryable")
	if carryable:
		carryable.queue_free()


func _bump(t: float, start: float, end: float) -> float:
	if t <= start or t >= end:
		return 0.0
	var k := (t - start) / (end - start)
	return smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.7, 1.0, k))
