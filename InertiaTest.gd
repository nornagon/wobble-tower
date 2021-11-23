extends Node2D

func _ready():
	yield(get_tree(), "idle_frame")
	print($Diamond.inertia)
	print($Square.inertia)
