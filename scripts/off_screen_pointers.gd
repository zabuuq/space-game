extends Control
class_name OffScreenPointers

var main_node: Node2D
var pointer_size := 10.0

func _process(_delta: float) -> void:
	if main_node == null or main_node.world_node == null:
		return
	
	# Match position and size to world_node, but don't clip
	position = main_node.world_node.position
	size = main_node.world_node.size
	scale = main_node.world_node.scale
	
	queue_redraw()

func _draw() -> void:
	if main_node == null or main_node.world_node == null:
		return
		
	var camera_rect = Rect2(Vector2.ZERO, size)
	
	# Only show pointers for Large map
	if main_node.current_play_area_size != 1:
		return
		
	var local_id = multiplayer.get_unique_id()
	if local_id == 0:
		return
		
	var all_ships = main_node._get_all_ships()
	
	for ship in all_ships:
		var ship_owner = ship.get_multiplayer_authority()
		if ship_owner == local_id or ship_owner == -1:
			continue
			
		var camera_center = main_node._get_camera_target_position()
		var dx = ship.position.x - camera_center.x
		var dy = ship.position.y - camera_center.y
		
		if main_node.current_edge_wrapping:
			var world_size = main_node.world_bounds.size
			if dx > world_size.x * 0.5:
				dx -= world_size.x
			elif dx < -world_size.x * 0.5:
				dx += world_size.x
				
			if dy > world_size.y * 0.5:
				dy -= world_size.y
			elif dy < -world_size.y * 0.5:
				dy += world_size.y
				
		var ship_global_pos = (camera_rect.size * 0.5) + Vector2(dx, dy)
		
		# If the ship is visible inside the camera rect, no pointer needed
		if camera_rect.grow(10.0).has_point(ship_global_pos):
			continue
		
		var center = camera_rect.size * 0.5
		var dir = (ship_global_pos - center).normalized()
		
		if dir.x == 0 and dir.y == 0:
			continue
			
		# Calculate intersection with a slightly shrunken rectangle to ensure full visibility
		var margin = pointer_size * 2.0
		var inner_size = size - Vector2(margin * 2.0, margin * 2.0)
		
		var t_x = INF
		if dir.x > 0:
			t_x = (inner_size.x * 0.5) / dir.x
		elif dir.x < 0:
			t_x = -(inner_size.x * 0.5) / dir.x
			
		var t_y = INF
		if dir.y > 0:
			t_y = (inner_size.y * 0.5) / dir.y
		elif dir.y < 0:
			t_y = -(inner_size.y * 0.5) / dir.y
			
		var t = min(t_x, t_y)
		var edge_pos = center + dir * t
		
		_draw_pointer(edge_pos, dir, ship.ship_color)

func _draw_pointer(pos: Vector2, dir: Vector2, color: Color) -> void:
	var perp = Vector2(-dir.y, dir.x)
	var points = PackedVector2Array([
		pos + dir * pointer_size,
		pos - dir * pointer_size + perp * (pointer_size * 0.7),
		pos - dir * pointer_size - perp * (pointer_size * 0.7)
	])
	
	draw_colored_polygon(points, color)
	draw_polyline(points, Color.BLACK, 1.5, true)
