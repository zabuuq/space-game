extends Node

func _ready() -> void:
	print("Starting automated tests via GUT...")
	var gut_node = load("res://addons/gut/gut.gd").new()
	add_child(gut_node)
	gut_node.add_directory("res://tests")
	gut_node.test_scripts()

