extends "res://tools/import/mesh_builder.gd"

const WOOD := preload("res://assets/materials/environment/wooden_planks.tres")

const SOUL := Color(0.62, 1.0, 0.82)

const BELLY := 0.05

const VIAL_SIDES := 9
const VIAL_GLASS: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.026, 0.002), Vector2(0.037, 0.022), Vector2(0.039, 0.055),
	Vector2(0.03, 0.085), Vector2(0.015, 0.098), Vector2(0.014, 0.118), Vector2(0.018, 0.122),
	Vector2(0.0, 0.122),
]
const VIAL_CORK: Array[Vector2] = [
	Vector2(0.0, 0.11), Vector2(0.0125, 0.11), Vector2(0.0145, 0.132), Vector2(0.0135, 0.14),
	Vector2(0.0, 0.141),
]
const VIAL_SEAL: Array[Vector2] = [
	Vector2(0.0, 0.112), Vector2(0.02, 0.112), Vector2(0.021, 0.118), Vector2(0.0, 0.119),
]

const UV_SCALE := 4.0
const SIZE := 1.6


func _init() -> void:
	uv_scale = UV_SCALE
	mesh_scale = SIZE
	quit(0 if _save(_build_vial(), "soul_bottle.res") else 1)


func _build_vial() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var down := Transform3D(Basis.IDENTITY, Vector3(0.0, -BELLY, 0.0))
	var cork := _begin()
	_lathe(cork, VIAL_CORK, 6, down)
	_commit(mesh, cork, WOOD)
	var seal := _begin()
	_lathe(seal, VIAL_SEAL, 7, down)
	_commit(mesh, seal, _wax())
	var glass := _begin()
	_lathe(glass, VIAL_GLASS, VIAL_SIDES, down)
	_commit(mesh, glass, _glass())
	return mesh


func _glass() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.72, 0.92, 0.9, 0.25)
	glass.roughness = 0.08
	glass.rim_enabled = true
	glass.rim = 0.6
	glass.emission_enabled = true
	glass.emission = SOUL * 0.12
	return glass


func _wax() -> StandardMaterial3D:
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.62, 0.16, 0.14)
	wax.roughness = 0.5
	return wax
