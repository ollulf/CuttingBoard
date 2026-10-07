extends "res://tools/import/mesh_builder.gd"

## Builds the ten nail gun concepts and their ammo (docs/concepts/nail-gun.md): homemade, mechanical
## one-shot guns that a wooden puppet could have knocked together in a shed. Each fires
## one nail and has to be re-armed by hand. They are concept models, blocky on purpose:
## boxes, turned rods, rope lashing, coil springs and the nail sitting in the barrel.
##
## Laid out like the saw, the way a HandSlot holds things: the middle of the grip sits
## at the origin and runs along +Y, the barrel points forward along -Z.
##
##   godot --headless --path cutting-board -s res://tools/import/build_nail_guns.gd

const DARK_WOOD := preload("res://assets/materials/environment/dark_planks.tres")
const LIGHT_WOOD := preload("res://assets/materials/environment/wooden_planks.tres")
const METAL := preload("res://assets/materials/environment/metal.tres")
const FABRIC := preload("res://assets/materials/environment/fabric_white.tres")

const UV_SCALE := 3.0

var _rope: StandardMaterial3D
var _leather: StandardMaterial3D
## The open surface per material while one gun is being built.
var _tools := {}


func _init() -> void:
	uv_scale = UV_SCALE
	_rope = FABRIC.duplicate()
	_rope.albedo_color = Color(0.78, 0.64, 0.42)
	_leather = FABRIC.duplicate()
	_leather.albedo_color = Color(0.32, 0.2, 0.13)
	var ok := true
	for gun in [["nail_gun_a_lever_bolt.res", _build_lever_bolt],
			["nail_gun_b_rope_twister.res", _build_rope_twister],
			["nail_gun_c_band_catapult.res", _build_band_catapult],
			["nail_gun_d_bellows_puffer.res", _build_bellows_puffer],
			["nail_gun_e_clockwork_knocker.res", _build_clockwork_knocker],
			["nail_gun_f_log_bombard.res", _build_log_bombard],
			["nail_gun_g_churn_thumper.res", _build_churn_thumper],
			["nail_gun_h_bellows_horn.res", _build_bellows_horn],
			["nail_gun_i_keg_cranker.res", _build_keg_cranker],
			["nail_gun_j_trough_swinger.res", _build_trough_swinger],
			["nail_ammo_railroad_spike.res", _build_ammo_spike],
			["nail_ammo_coffin_nails.res", _build_ammo_coffin_nails],
			["nail_ammo_plain_nail.res", _build_ammo_plain_nail]]:
		_tools = {}
		(gun[1] as Callable).call()
		var mesh := ArrayMesh.new()
		for material in _tools:
			_commit(mesh, _tools[material], material)
		ok = _save(mesh, gun[0]) and ok
	quit(0 if ok else 1)


## A: a spring-loaded hammer bolt. A pipe barrel lashed to a plank stock; behind it a
## coil spring and a wooden bolt that a long under-lever pulls back until a peg catches it.
func _build_lever_bolt() -> void:
	_grip(DARK_WOOD, 0.0)
	_box(DARK_WOOD, Vector3(0, 0.085, -0.1), Vector3(0.045, 0.05, 0.34))
	_rod(METAL, Vector3(0, 0.125, 0.0), Vector3(0, 0.125, -0.36), 0.016, 7)
	_spring(Vector3(0, 0.125, 0.07), Vector3(0, 0.125, 0.0), 0.014, 5, 0.003)
	_box(LIGHT_WOOD, Vector3(0, 0.125, 0.09), Vector3(0.03, 0.03, 0.05))
	# The lever: hinged at the front under the stock, its handle running back over the fist.
	_rod(METAL, Vector3(0.03, 0.07, -0.24), Vector3(0.03, -0.02, 0.06), 0.006, 5)
	_rod(METAL, Vector3(0.03, 0.07, -0.24), Vector3(0.03, 0.125, 0.1), 0.004, 4)
	_box(DARK_WOOD, Vector3(0.03, -0.035, 0.07), Vector3(0.02, 0.05, 0.025))
	_rod(METAL, Vector3(-0.03, 0.07, -0.24), Vector3(0.035, 0.07, -0.24), 0.007, 5)
	_lash(Vector3(0, 0.11, -0.08), 0.045)
	_lash(Vector3(0, 0.11, -0.26), 0.045)
	_rod(METAL, Vector3(0, 0.05, -0.03), Vector3(0, 0.02, -0.05), 0.005, 4)
	_nail(Vector3(0, 0.125, -0.39), Vector3(0, 0.125, -0.31))


## B: a little torsion crossbow. A crossbar with a twisted rope skein in each end drives
## two short arms; their string pulls a sled that knocks the nail down a grooved plank.
func _build_rope_twister() -> void:
	_grip(DARK_WOOD, 0.0)
	_box(LIGHT_WOOD, Vector3(0, 0.08, -0.15), Vector3(0.05, 0.035, 0.44))
	_box(DARK_WOOD, Vector3(0, 0.08, -0.33), Vector3(0.26, 0.05, 0.05))
	for side in [-1.0, 1.0]:
		var skein := Vector3(side * 0.09, 0.08, -0.33)
		_spring(skein + Vector3(0, -0.045, 0), skein + Vector3(0, 0.045, 0), 0.016, 3, 0.006, _rope)
		_rod(_rope, skein + Vector3(0, -0.045, 0), skein + Vector3(0, 0.045, 0), 0.012, 6)
		var arm_tip := skein + Vector3(side * 0.07, 0.0, 0.12)
		_rod(LIGHT_WOOD, skein, arm_tip, 0.008, 5)
		_rod(_rope, arm_tip, Vector3(0, 0.105, 0.02), 0.003, 4)
	_box(METAL, Vector3(0, 0.105, 0.02), Vector3(0.03, 0.02, 0.03))
	# The windlass at the back that winds the sled home.
	_rod(DARK_WOOD, Vector3(-0.05, 0.08, 0.06), Vector3(0.05, 0.08, 0.06), 0.012, 6)
	_rod(METAL, Vector3(0.05, 0.08, 0.06), Vector3(0.05, 0.03, 0.09), 0.005, 4)
	_rod(DARK_WOOD, Vector3(0.05, 0.03, 0.09), Vector3(0.08, 0.03, 0.09), 0.008, 5)
	_lash(Vector3(0, 0.08, -0.3), 0.04)
	_nail(Vector3(0, 0.106, -0.36), Vector3(0, 0.106, -0.28))


## C: a slingshot pistol. A forked branch out front holds two thick rubber bands; their
## leather pouch is a striker block, pulled back to a clothes-peg latch over the grip.
func _build_band_catapult() -> void:
	_grip(LIGHT_WOOD, 0.0)
	_box(LIGHT_WOOD, Vector3(0, 0.08, -0.1), Vector3(0.035, 0.035, 0.3))
	# The fork: a branch lashed to the front of the stock, its prongs leaning out.
	_rod(DARK_WOOD, Vector3(0, 0.06, -0.25), Vector3(0, 0.13, -0.26), 0.012, 6)
	for side in [-1.0, 1.0]:
		var tip := Vector3(side * 0.06, 0.2, -0.27)
		_rod(DARK_WOOD, Vector3(0, 0.13, -0.26), tip, 0.01, 6)
		_rod(_leather, tip + Vector3(0, -0.01, 0), Vector3(side * 0.015, 0.12, 0.05), 0.005, 4)
	_box(_leather, Vector3(0, 0.12, 0.055), Vector3(0.04, 0.03, 0.025))
	# The clothes-peg latch that holds the pouch back.
	_box(LIGHT_WOOD, Vector3(0, 0.11, 0.09), Vector3(0.02, 0.012, 0.07), Basis(Vector3.RIGHT, 0.2))
	_box(LIGHT_WOOD, Vector3(0, 0.125, 0.09), Vector3(0.02, 0.012, 0.07), Basis(Vector3.RIGHT, -0.15))
	_spring(Vector3(-0.012, 0.118, 0.09), Vector3(0.012, 0.118, 0.09), 0.008, 2, 0.002)
	_box(METAL, Vector3(0, 0.105, -0.08), Vector3(0.012, 0.012, 0.26))
	_lash(Vector3(0, 0.08, -0.24), 0.035)
	_lash(Vector3(0, 0.08, 0.0), 0.035)
	_nail(Vector3(0, 0.112, -0.2), Vector3(0, 0.112, -0.12))


## D: a bellows puffer. A pair of hinged boards with a leather gusset under a long
## pipe; slamming the boards shut blows the nail out. A pump rod on top reopens them.
func _build_bellows_puffer() -> void:
	_grip(DARK_WOOD, 0.0)
	var hinge := Vector3(0, 0.06, -0.3)
	_box(DARK_WOOD, Vector3(0, 0.05, -0.15), Vector3(0.11, 0.015, 0.3))
	var open := Basis(Vector3.RIGHT, 0.28)
	var top_centre := hinge + open * Vector3(0, 0.015, 0.15)
	_box(DARK_WOOD, top_centre, Vector3(0.11, 0.015, 0.3), open)
	# The leather gusset round the open sides, as a wedge.
	for side in [-1.0, 1.0]:
		var x: float = side * 0.052
		_face(_tool(_leather), [Vector3(x, 0.058, -0.3), Vector3(x, 0.058, 0.0),
				Vector3(x, hinge.y + (open * Vector3(0, 0, 0.3)).y + 0.01, (hinge + open * Vector3(0, 0, 0.3)).z)],
				Vector3(side, 0, 0))
	var back_top := hinge + open * Vector3(0, 0.01, 0.3)
	_face(_tool(_leather), [Vector3(-0.052, 0.058, 0.0), Vector3(0.052, 0.058, 0.0),
			back_top + Vector3(0.052, 0, 0), back_top + Vector3(-0.052, 0, 0)], Vector3(0, 0, 1))
	_rod(METAL, Vector3(0, 0.05, -0.3), Vector3(0, 0.05, -0.42), 0.014, 7)
	_rod(METAL, Vector3(0, 0.05, -0.29), Vector3(0, 0.05, -0.31), 0.022, 7)
	# The pump handle bolted on the top board.
	var knob := top_centre + Vector3(0, 0.07, 0.08)
	_rod(LIGHT_WOOD, top_centre + Vector3(0, 0.0, 0.08), knob, 0.007, 5)
	_rod(LIGHT_WOOD, knob + Vector3(-0.04, 0, 0), knob + Vector3(0.04, 0, 0), 0.012, 6)
	_lash(Vector3(0, 0.05, -0.36), 0.03)
	_nail(Vector3(0, 0.05, -0.45), Vector3(0, 0.05, -0.37))


## E: a clockwork knocker. A turned drum holds a wound spring; a big key on its side
## winds it, and a notched cog lets a striker arm snap down once onto the nail.
func _build_clockwork_knocker() -> void:
	_grip(DARK_WOOD, 0.0)
	_box(DARK_WOOD, Vector3(0, 0.075, -0.12), Vector3(0.04, 0.035, 0.32))
	var axle := Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.0, 0.14, 0.0))
	var drum: Array[Vector2] = [Vector2(0, -0.035), Vector2(0.055, -0.035), Vector2(0.055, 0.035), Vector2(0, 0.035)]
	_lathe(_tool(LIGHT_WOOD), drum, 10, axle)
	for k in 10:
		var angle := TAU * k / 10.0
		var at := Vector3(0.0, 0.14 + sin(angle) * 0.058, cos(angle) * 0.058)
		_box(METAL, at, Vector3(0.074, 0.01, 0.01), Basis(Vector3.RIGHT, -angle))
	# The wind-up key on the right side.
	_rod(METAL, Vector3(0.035, 0.14, 0), Vector3(0.075, 0.14, 0), 0.006, 5)
	_box(METAL, Vector3(0.08, 0.14, 0), Vector3(0.01, 0.09, 0.02))
	_box(METAL, Vector3(0.08, 0.185, 0), Vector3(0.01, 0.025, 0.05))
	_box(METAL, Vector3(0.08, 0.095, 0), Vector3(0.01, 0.025, 0.05))
	# The striker arm, cocked up and back, with a hammer head over the nail.
	_rod(LIGHT_WOOD, Vector3(0, 0.14, -0.04), Vector3(0, 0.2, -0.2), 0.009, 5)
	_box(METAL, Vector3(0, 0.2, -0.22), Vector3(0.035, 0.03, 0.04))
	_rod(METAL, Vector3(0, 0.105, -0.16), Vector3(0, 0.105, -0.34), 0.012, 6)
	_lash(Vector3(0, 0.09, -0.3), 0.035)
	_nail(Vector3(0, 0.105, -0.37), Vector3(0, 0.105, -0.29))


## Round 2: blunderbusses with big nails. They don't have to look like guns: a log, a churn,
## a bellows, a nail keg and a nailing trough, each still a one-shot that is re-armed by hand.

## F: a log bombard. A hollowed log with a flared mouth, bound with iron hoops; a spring ram
## inside is hauled back by a rope toggle out the back and fires a fistful of coffin nails.
func _build_log_bombard() -> void:
	_grip(DARK_WOOD, 0.0)
	_box(DARK_WOOD, Vector3(0, 0.03, 0.12), Vector3(0.04, 0.05, 0.16), Basis(Vector3.RIGHT, 0.2))
	var bore: Array[Vector2] = [Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 0.4), Vector2(0.085, 0.52),
			Vector2(0.07, 0.52), Vector2(0.03, 0.42)]
	_lathe(_tool(DARK_WOOD), bore, 9, _along(Vector3(0, 0.1, 0.08), Vector3(0, 0.1, -0.5)))
	for z in [0.04, -0.12, -0.28]:
		_rod(METAL, Vector3(0, 0.1, z + 0.01), Vector3(0, 0.1, z - 0.01), 0.054, 9)
	_rod(METAL, Vector3(0, 0.1, -0.38), Vector3(0, 0.1, -0.4), 0.064, 9)
	# The ram's spring and rope toggle sticking out the back.
	_spring(Vector3(0, 0.1, 0.16), Vector3(0, 0.1, 0.08), 0.02, 4, 0.003)
	_rod(_rope, Vector3(0, 0.1, 0.16), Vector3(0, 0.1, 0.22), 0.005, 4)
	_rod(LIGHT_WOOD, Vector3(-0.04, 0.1, 0.22), Vector3(0.04, 0.1, 0.22), 0.01, 6)
	_lash(Vector3(0, 0.07, -0.02), 0.06)
	for k in 5:
		var angle := TAU * k / 5.0
		var at := Vector3(cos(angle) * 0.03, 0.1 + sin(angle) * 0.03, -0.5)
		_nail(at + Vector3(cos(angle) * 0.01, sin(angle) * 0.01, -0.05), at + Vector3(0, 0, 0.06), 0.006)


## G: a churn thumper. A butter churn laid on its side on a stock; its dasher is pulled back
## against two strips of inner tube and latched, then slams a railroad spike out of the lid.
func _build_churn_thumper() -> void:
	_grip(LIGHT_WOOD, 0.0)
	_box(LIGHT_WOOD, Vector3(0, 0.04, 0.16), Vector3(0.04, 0.06, 0.2), Basis(Vector3.RIGHT, 0.15))
	var churn: Array[Vector2] = [Vector2(0, 0), Vector2(0.07, 0), Vector2(0.06, 0.34), Vector2(0, 0.34)]
	_lathe(_tool(LIGHT_WOOD), churn, 10, _along(Vector3(0, 0.12, 0.06), Vector3(0, 0.12, -0.28)))
	for hoop in [[0.02, 0.073], [-0.22, 0.066]]:
		_rod(METAL, Vector3(0, 0.12, hoop[0] + 0.01), Vector3(0, 0.12, hoop[0] - 0.01), hoop[1], 10)
	# The dasher rod and its cross handle, pulled back; inner-tube straps run to the front.
	_rod(DARK_WOOD, Vector3(0, 0.12, 0.06), Vector3(0, 0.12, 0.24), 0.01, 6)
	_rod(DARK_WOOD, Vector3(-0.06, 0.12, 0.24), Vector3(0.06, 0.12, 0.24), 0.013, 6)
	for side in [-1.0, 1.0]:
		_rod(_leather, Vector3(side * 0.055, 0.12, 0.24), Vector3(side * 0.065, 0.12, -0.26), 0.006, 4)
	_box(METAL, Vector3(0, 0.07, 0.1), Vector3(0.015, 0.03, 0.03))
	_spike(Vector3(0, 0.12, -0.42), Vector3(0, 0.12, -0.27))


## H: a bellows horn. A big pair of hearth bellows with a tin funnel flaring off the nozzle;
## clapping the handles together blasts a scatter of coffin nails out of the horn.
func _build_bellows_horn() -> void:
	_box(DARK_WOOD, Vector3(0, 0.0, -0.05), Vector3(0.16, 0.015, 0.26))
	var open := Basis(Vector3.RIGHT, 0.35)
	var hinge := Vector3(0, 0.01, -0.18)
	var back_top := hinge + open * Vector3(0, 0.01, 0.26)
	_box(DARK_WOOD, hinge + open * Vector3(0, 0.01, 0.13), Vector3(0.16, 0.015, 0.26), open)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.075
		_face(_tool(_leather), [Vector3(x, 0.008, -0.18), Vector3(x, 0.008, 0.08), Vector3(x, back_top.y, back_top.z)],
				Vector3(side, 0, 0))
	_face(_tool(_leather), [Vector3(-0.075, 0.008, 0.08), Vector3(0.075, 0.008, 0.08),
			back_top + Vector3(0.075, 0, 0), back_top + Vector3(-0.075, 0, 0)], Vector3(0, 0, 1))
	# Two handles running back, one per board.
	_rod(DARK_WOOD, Vector3(0, 0.0, 0.08), Vector3(0, -0.01, 0.2), 0.012, 6)
	_rod(DARK_WOOD, back_top, hinge + open * Vector3(0, 0.01, 0.38), 0.012, 6)
	var horn: Array[Vector2] = [Vector2(0.015, 0), Vector2(0.025, 0.12), Vector2(0.08, 0.28), Vector2(0.074, 0.28),
			Vector2(0.02, 0.12), Vector2(0.01, 0)]
	_lathe(_tool(METAL), horn, 10, _along(Vector3(0, 0.02, -0.17), Vector3(0, 0.05, -0.5)))
	_lash(Vector3(0, 0.02, -0.2), 0.03)
	for k in 4:
		var angle := TAU * k / 4.0 + 0.4
		var at := Vector3(cos(angle) * 0.035, 0.05 + sin(angle) * 0.035, -0.43)
		_nail(at + Vector3(0, 0, -0.04), at + Vector3(0, 0, 0.06), 0.006)


## I: a keg cranker. A small nail keg rides on top of a stock as a hopper; one turn of the
## side crank drops the next spike in the breech and winds the flat spring that kicks it out.
func _build_keg_cranker() -> void:
	_grip(DARK_WOOD, 0.0)
	_box(DARK_WOOD, Vector3(0, 0.07, -0.08), Vector3(0.05, 0.04, 0.36))
	var keg: Array[Vector2] = [Vector2(0, 0), Vector2(0.06, 0), Vector2(0.075, 0.07), Vector2(0.06, 0.14), Vector2(0, 0.14)]
	_lathe(_tool(LIGHT_WOOD), keg, 10, _along(Vector3(0, 0.1, 0.0), Vector3(0, 0.24, 0.0)))
	for y in [0.13, 0.21]:
		_rod(METAL, Vector3(0, y - 0.006, 0), Vector3(0, y + 0.006, 0), 0.071, 10)
	# The crank on the right side and the flat spring along the stock.
	_rod(METAL, Vector3(0.02, 0.07, 0.0), Vector3(0.08, 0.07, 0.0), 0.007, 5)
	_rod(METAL, Vector3(0.08, 0.07, 0.0), Vector3(0.08, 0.0, 0.05), 0.006, 5)
	_rod(DARK_WOOD, Vector3(0.08, 0.0, 0.05), Vector3(0.12, 0.0, 0.05), 0.011, 6)
	_box(METAL, Vector3(0, 0.1, 0.12), Vector3(0.03, 0.006, 0.12), Basis(Vector3.RIGHT, 0.25))
	_rod(METAL, Vector3(0, 0.1, -0.05), Vector3(0, 0.1, -0.34), 0.022, 8)
	_rod(METAL, Vector3(0, 0.1, -0.33), Vector3(0, 0.1, -0.36), 0.034, 8)
	_lash(Vector3(0, 0.09, -0.24), 0.045)
	_spike(Vector3(0, 0.1, -0.41), Vector3(0, 0.1, -0.27))


## J: a trough swinger. A nailing trough on a stock with a mallet on a springy ash arm cocked
## up behind it; let go, the mallet swings down and drives the spike down the trough.
func _build_trough_swinger() -> void:
	_grip(DARK_WOOD, 0.0)
	for side in [-1.0, 1.0]:
		_box(LIGHT_WOOD, Vector3(side * 0.022, 0.08, -0.14), Vector3(0.012, 0.05, 0.44), Basis(Vector3.FORWARD, side * 0.6))
	_box(DARK_WOOD, Vector3(0, 0.05, -0.14), Vector3(0.05, 0.02, 0.44))
	# The ash arm, pegged at the back of the trough, bent up and back with the mallet on top.
	var pivot := Vector3(0, 0.07, 0.06)
	var head := Vector3(0, 0.28, 0.12)
	_rod(LIGHT_WOOD, pivot, head, 0.01, 6)
	_box(DARK_WOOD, head + Vector3(0, 0.02, 0.0), Vector3(0.06, 0.06, 0.09), Basis(Vector3.RIGHT, -0.3))
	_rod(METAL, pivot + Vector3(-0.035, 0, 0), pivot + Vector3(0.035, 0, 0), 0.007, 5)
	_spring(pivot + Vector3(-0.03, 0, 0), pivot + Vector3(-0.012, 0, 0), 0.016, 3, 0.003)
	_rod(_rope, head, Vector3(0, 0.09, 0.14), 0.004, 4)
	_rod(METAL, Vector3(0, 0.08, 0.14), Vector3(0, 0.1, 0.16), 0.005, 4)
	_lash(Vector3(0, 0.07, -0.3), 0.045)
	_spike(Vector3(0, 0.085, -0.4), Vector3(0, 0.085, -0.24))


## The ammo on its own, for the scale shot: a railroad spike, a bundle of coffin nails tied
## with cord, and one of the round 1 nails.
func _build_ammo_spike() -> void:
	_spike(Vector3(0, 0, -0.08), Vector3(0, 0, 0.08))


func _build_ammo_coffin_nails() -> void:
	for k in 5:
		var at := Vector3((k - 2) * 0.014, absf(k - 2) * -0.004, 0)
		_nail(at + Vector3(0, 0, -0.06), at + Vector3(0, 0, 0.06), 0.006)
	_lash(Vector3(0, -0.004, 0), 0.05)


func _build_ammo_plain_nail() -> void:
	_nail(Vector3(0, 0, -0.04), Vector3(0, 0, 0.04))


## A railroad spike with its point at `tip` and its head at `head`: a square shank with a
## chisel point and a wide head with a lip bent out to one side.
func _spike(tip: Vector3, head: Vector3) -> void:
	var length := tip.distance_to(head)
	var profile: Array[Vector2] = [Vector2(0, 0), Vector2(0.011, 0.03), Vector2(0.011, length),
			Vector2(0.022, length), Vector2(0.022, length + 0.012), Vector2(0, length + 0.012)]
	var frame := _along(tip, head)
	frame.basis = frame.basis * Basis(Vector3.UP, PI * 0.25)
	_lathe(_tool(METAL), profile, 4, frame)
	_box(METAL, head + (head - tip).normalized() * 0.006 + Vector3(0, 0.016, 0), Vector3(0.026, 0.016, 0.014))


## The pistol grip under the fist: a slab of wood with a cut-off butt.
func _grip(material: Material, lean: float) -> void:
	_box(material, Vector3(0, -0.01, 0.015), Vector3(0.035, 0.15, 0.045), Basis(Vector3.RIGHT, lean - 0.25))


func _tool(material: Material) -> SurfaceTool:
	if not _tools.has(material):
		_tools[material] = _begin()
	return _tools[material]


## A box of `size` turned by `basis` round its `center`.
func _box(material: Material, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var tool := _tool(material)
	var h := size * 0.5
	for axis in 3:
		for s in [-1.0, 1.0]:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var corners: Array = []
			for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var local := Vector3.ZERO
				local[axis] = s * h[axis]
				local[u] = c[0] * h[u]
				local[v] = c[1] * h[v]
				corners.append(center + basis * local)
			var facing := Vector3.ZERO
			facing[axis] = s
			_face(tool, corners, basis * facing)


## A turned rod of `radius` from `a` to `b`.
func _rod(material: Material, a: Vector3, b: Vector3, radius: float, sides: int) -> void:
	var length := a.distance_to(b)
	var profile: Array[Vector2] = [Vector2(0, 0), Vector2(radius, 0), Vector2(radius, length), Vector2(0, length)]
	_lathe(_tool(material), profile, sides, _along(a, b))


## The transform that puts a lathe's +Y axis on the line from `a` to `b`.
func _along(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), a)


## A coil of wire from `a` to `b`, as short straight rods.
func _spring(a: Vector3, b: Vector3, radius: float, turns: int, wire: float, material: Material = METAL) -> void:
	var frame := _along(a, b)
	var length := a.distance_to(b)
	var steps := turns * 8
	var last := Vector3.ZERO
	for k in steps + 1:
		var t := float(k) / steps
		var angle := TAU * turns * t
		var point := frame * Vector3(cos(angle) * radius, t * length, sin(angle) * radius)
		if k > 0:
			_rod(material, last, point, wire, 4)
		last = point


## A rope binding round the stock at `center`: three turns of cord, across the X axis.
func _lash(center: Vector3, radius: float) -> void:
	for turn in 3:
		var offset := Vector3(0, 0, (turn - 1) * 0.008)
		var last := Vector3.ZERO
		for k in 9:
			var angle := TAU * k / 8.0
			var point := center + offset + Vector3(cos(angle) * radius * 0.7, sin(angle) * radius * 0.75, 0)
			if k > 0:
				_rod(_rope, last, point, 0.0035, 4)
			last = point


## A nail with its point at `tip` and its head at `head`.
func _nail(tip: Vector3, head: Vector3, radius := 0.004) -> void:
	var length := tip.distance_to(head)
	var cap := radius * 2.5
	var profile: Array[Vector2] = [Vector2(0, 0), Vector2(radius, radius * 3.0), Vector2(radius, length),
			Vector2(cap, length), Vector2(cap, length + radius), Vector2(0, length + radius)]
	_lathe(_tool(METAL), profile, 6, _along(tip, head))
