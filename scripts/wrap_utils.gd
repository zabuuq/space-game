extends RefCounted
class_name WrapUtils

## Centralized logic for Asteroids-style screen wrapping.

## Returns a wrapped position within the given bounds.
static func wrap_pos(pos: Vector2, bounds: Rect2, enabled: bool) -> Vector2:
	if not enabled:
		return pos
	
	var wrapped := pos
	if wrapped.x < bounds.position.x: wrapped.x += bounds.size.x
	elif wrapped.x > bounds.end.x: wrapped.x -= bounds.size.x
	if wrapped.y < bounds.position.y: wrapped.y += bounds.size.y
	elif wrapped.y > bounds.end.y: wrapped.y -= bounds.size.y
	return wrapped

## Returns the 8 adjacent offsets needed for seamless visual wrapping.
static func get_wrap_offsets(bounds: Rect2, enabled: bool) -> Array[Vector2]:
	var offsets: Array[Vector2] = [Vector2.ZERO]
	if not enabled:
		return offsets
		
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
	return offsets
