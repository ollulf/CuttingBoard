class_name MaskWear
extends RefCounted

## What every worn mask shares, whoever wears it — a human face (HumanBody) or a walking
## chair's head (WalkingChair): the crack drawn on a worn-down face, and the roll for what
## a mask on a face that dies becomes.


## Draws a mask's wear on its face: nothing above half of `ratio`, then a crack running
## further down it the less is left.
static func show_crack(face: Node3D, ratio: float) -> void:
	if face == null:
		return
	var crack := 0.0 if ratio > 0.5 else remap(ratio, 0.5, 0.0, 0.4, 1.0)
	for node in face.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var shaded := mi.material_override as ShaderMaterial
		if shaded == null:
			var authored := mi.get_active_material(0) as ShaderMaterial
			if authored == null or crack == 0.0:
				continue
			# A copy of its own, so one cracked face does not crack every mask of its kind.
			shaded = authored.duplicate()
			mi.material_override = shaded
		shaded.set_shader_parameter(&"crack", crack)


## A mask on a face that dies, `durability` left of it: shattered (`shatter_chance`, drawn
## from `rng`), or still its own kind with a share of its durability in `left` (never more
## than it had). Returns [what it now is, its durability (-1: as authored)].
static func roll_on_death(rng: RandomNumberGenerator, mask: MaskData, durability: int,
		shatter_chance: float, left: Vector2, shattered: ItemData) -> Array:
	if rng.randf() < shatter_chance:
		return [shattered, -1]
	var share := rng.randf_range(left.x, left.y)
	return [mask, clampi(roundi(mask.durability * share), 1, maxi(durability, 1))]
