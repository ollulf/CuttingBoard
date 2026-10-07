extends "res://tools/import/mesh_builder.gd"

## Builds the soul in a bottle's mesh (the spirit of a mask, caught by the Mask-Monger):
## a corked glass vial, round-bellied, a dab of red wax sealing the cork. The soul itself
## is not part of the mesh: it is the swirl sphere in scenes/items/soul_bottle.tscn,
## floating in the vial's hollow round the origin.
##
## Built the same way as the wood glue (tools/import/build_wood_glue.gd): lathed
## profiles, flat shaded, laid out the way a HandSlot holds things.
##
##   godot --headless --path cutting-board -s res://tools/import/build_soul_bottle.gd

const WOOD := preload("res://assets/materials/environment/wooden_planks.tres")

## The glass's faint inner glow.
const SOUL := Color(0.62, 1.0, 0.82)

## Profiles are (radius, height) pairs in metres, from the bottom up the outside and back
## down the inside, as on the wood glue. The vial is lowered by BELLY so the middle of
## its hollow, where the soul floats, is at the origin.
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

## Texture repeats per metre, as on the wood glue.
const UV_SCALE := 4.0
## Scaled up like the wood glue, to sit in the larger-than-life hands at the same size.
const SIZE := 1.6


func _init() -> void:
	uv_scale = UV_SCALE
	mesh_scale = SIZE
	quit(0 if _save(_build_vial(), "soul_bottle.res") else 1)


## A corked glass vial, a dab of wax over the cork.
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
