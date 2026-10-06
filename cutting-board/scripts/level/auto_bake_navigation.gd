extends NavigationRegion3D

## Bakes this region's navigation mesh when the level loads, if it has not been baked in
## the editor already. That keeps NPCs walking while the level is still being blocked
## out; once the level settles, press "Bake NavigationMesh" in the editor and this step
## is skipped. Geometry is gathered from nodes in the mesh's source group, so a new
## building joins the walkable world by being put in that group.


func _ready() -> void:
	if navigation_mesh and navigation_mesh.get_polygon_count() == 0:
		# Deferred so every sibling in the level has entered the tree to be parsed.
		bake_navigation_mesh.call_deferred(true)
