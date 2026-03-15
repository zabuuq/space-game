extends Node2D
class_name Starfield

const STAR_COUNT_PER_SCREEN = 150
var world_bounds := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))
var edge_wrapping := true

var multimesh_instance: MultiMeshInstance2D

func _ready() -> void:
	multimesh_instance = MultiMeshInstance2D.new()
	multimesh_instance.modulate = Color(0.5, 0.5, 0.5)
	add_child(multimesh_instance)

func generate_stars(bounds: Rect2, wrapping: bool) -> void:
	world_bounds = bounds
	edge_wrapping = wrapping
	
	var area_ratio = (bounds.size.x * bounds.size.y) / (1600.0 * 900.0)
	var num_stars = int(STAR_COUNT_PER_SCREEN * area_ratio)
	
	var offsets := [Vector2.ZERO]
	if wrapping:
		offsets.append_array([
			Vector2(bounds.size.x, 0),
			Vector2(-bounds.size.x, 0),
			Vector2(0, bounds.size.y),
			Vector2(0, -bounds.size.y),
			Vector2(bounds.size.x, bounds.size.y),
			Vector2(-bounds.size.x, bounds.size.y),
			Vector2(bounds.size.x, -bounds.size.y),
			Vector2(-bounds.size.x, -bounds.size.y)
		])
	
	var total_instances = num_stars * offsets.size()
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(2, 2)
	
	var multimesh = MultiMesh.new()
	multimesh.mesh = mesh
	multimesh.use_colors = false
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = total_instances
	
	seed(int(bounds.size.x * bounds.size.y))
	
	var index = 0
	var base_stars: Array[Vector2] = []
	for i in range(num_stars):
		var x = randf_range(bounds.position.x, bounds.end.x)
		var y = randf_range(bounds.position.y, bounds.end.y)
		base_stars.append(Vector2(x, y))
		
	for offset in offsets:
		for star in base_stars:
			var t = Transform2D(0, star + offset)
			multimesh.set_instance_transform_2d(index, t)
			index += 1
			
	multimesh_instance.multimesh = multimesh
