extends NavigationRegion3D


func _ready() -> void:
	if navigation_mesh and navigation_mesh.get_polygon_count() == 0:
		bake_navigation_mesh.call_deferred(true)
