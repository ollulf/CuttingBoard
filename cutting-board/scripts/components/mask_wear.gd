class_name MaskWear
extends RefCounted


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
			shaded = authored.duplicate()
			mi.material_override = shaded
		shaded.set_shader_parameter(&"crack", crack)


static func roll_on_death(rng: RandomNumberGenerator, mask: MaskData, durability: int,
		shatter_chance: float, left: Vector2, shattered: ItemData) -> Array:
	if rng.randf() < shatter_chance:
		return [shattered, -1]
	var share := rng.randf_range(left.x, left.y)
	return [mask, clampi(roundi(mask.durability * share), 1, maxi(durability, 1))]
