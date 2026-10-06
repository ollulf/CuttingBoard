class_name PaperDoll
extends Control

## The figure in the middle of the inventory's equipment column: a plain silhouette with
## whatever is worn drawn over it, so the four slots around it read as places on a body.
## It is drawn rather than a texture so it stays a few flat Tallow Fair shapes, crisp at
## any whole-number scale. It takes no input.
##
## The shapes are laid out on a 60 x 132 grid and stretched to the control's size.

const GRID := Vector2(60, 132)
const BODY_TOP := Color("#4a2c4a")
const BODY_BOTTOM := Color("#1a1020")
const COAT := Color("#5a3a58")
const HOOD := Color("#5a3a58")
const MASK := Color("#efe2c0")
const INK := Color("#07050a")
const FLAME := Color("#f0a838")
const AMBER := Color("#a8642a")

var _equipment: Equipment


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Draws what this loadout is wearing, and keeps up with it.
func bind(equipment: Equipment) -> void:
	if _equipment and _equipment.changed.is_connected(queue_redraw):
		_equipment.changed.disconnect(queue_redraw)
	_equipment = equipment
	if _equipment:
		_equipment.changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	_ellipse(Vector2(30, 14), Vector2(9, 11))
	_box(Rect2(26, 23, 8, 6))
	_shape([Vector2(15, 30), Vector2(45, 30), Vector2(42, 74), Vector2(18, 74)])
	_box(Rect2(8, 31, 7, 40))
	_box(Rect2(45, 31, 7, 40))
	_box(Rect2(19, 74, 9, 54))
	_box(Rect2(32, 74, 9, 54))
	if _equipment == null:
		return
	if not _equipment.is_free(Equipment.Slot.PACK):
		# The strap and the edge of the pack showing past the shoulder.
		_box(Rect2(44, 36, 5, 22), AMBER)
	if not _equipment.is_free(Equipment.Slot.BODY):
		_shape(
			[Vector2(13, 29), Vector2(47, 29), Vector2(49, 98), Vector2(11, 98)], COAT
		)
		_box(Rect2(30, 33, 1, 63), INK)
		for y in range(38, 92, 10):
			_box(Rect2(31, y, 2, 2), FLAME)
	if not _equipment.is_free(Equipment.Slot.HEAD):
		_ellipse(Vector2(30, 11), Vector2(11, 10), HOOD)
	if not _equipment.is_free(Equipment.Slot.MASK):
		_ellipse(Vector2(30, 15), Vector2(7, 9), MASK)
		_box(Rect2(26, 12, 2, 2), INK)
		_box(Rect2(32, 12, 2, 2), INK)
		_box(Rect2(28, 20, 4, 1), INK)


## How much one grid unit is on screen.
func _scale() -> Vector2:
	return size / GRID


## The silhouette's colour at a height on the grid: lit at the head, dark at the feet.
func _shade(y: float) -> Color:
	return BODY_TOP.lerp(BODY_BOTTOM, clampf(y / GRID.y, 0.0, 1.0))


## A filled polygon given in grid units. Left without a colour it takes the body's
## top-to-bottom shading, one colour per corner.
func _shape(points: Array, color := Color(0, 0, 0, 0)) -> void:
	var scaled := PackedVector2Array()
	var colors := PackedColorArray()
	for point: Vector2 in points:
		scaled.append(point * _scale())
		colors.append(color if color.a > 0.0 else _shade(point.y))
	draw_polygon(scaled, colors)


func _box(rect: Rect2, color := Color(0, 0, 0, 0)) -> void:
	_shape(
		[rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)],
		color,
	)


func _ellipse(center: Vector2, radius: Vector2, color := Color(0, 0, 0, 0)) -> void:
	var points := []
	for i in 20:
		var angle := TAU * i / 20.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_shape(points, color)
