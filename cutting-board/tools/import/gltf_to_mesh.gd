@tool
extends EditorScenePostImport

func _post_import(scene):
	iterate(scene)
	if first_mesh_instance:
		return first_mesh_instance
	else:
		return scene

var first_mesh_instance : MeshInstance3D
func iterate(node):
	if node != null:
		if node is MeshInstance3D and not first_mesh_instance:
			first_mesh_instance = node
			return
		for child in node.get_children():
			iterate(child)
