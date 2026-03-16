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

## Returns the shortest distance between two points, considering screen wrapping.
static func get_wrapped_distance(from: Vector2, to: Vector2, bounds: Rect2) -> float:
	return get_wrapped_vector(from, to, bounds).length()

## Returns the shortest vector between two points, considering screen wrapping.
static func get_wrapped_vector(from: Vector2, to: Vector2, bounds: Rect2) -> Vector2:
	var diff = to - from
	if diff.x > bounds.size.x / 2.0: diff.x -= bounds.size.x
	elif diff.x < -bounds.size.x / 2.0: diff.x += bounds.size.x
	if diff.y > bounds.size.y / 2.0: diff.y -= bounds.size.y
	elif diff.y < -bounds.size.y / 2.0: diff.y += bounds.size.y
	return diff
