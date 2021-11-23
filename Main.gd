extends Control

export (Array, PackedScene) var Shapes
export var shape_force = 200

var current_shape
var top = -INF
var all_time_top = -INF
var running = false

func save_score(score):
	var file = File.new()
	file.open("user://save.dat", File.WRITE)
	file.store_float(score)
	file.close()

func load_score():
	var file = File.new()
	if file.open("user://save.dat", File.READ) == OK:
		var score = file.get_float()
		file.close()
		return score
	return -INF

func drop():
	if current_shape:
		current_shape.applied_force = Vector2()
		current_shape.applied_torque = 0
	var shape = Shapes[randi() % Shapes.size()].instance()
	shape.rotation = (randi() % 4) * PI / 2
	shape.position = Vector2($Platform.position.x + (randf() - 0.5) * 100, 0)
	# godot's moment of inertia calculation is wrong for non-aabb shapes:
	# https://github.com/godotengine/godot/blob/11e03ae7f085b53505c242cf92615f7170c779ce/servers/physics_2d/godot_body_2d.cpp#L88
	# this value is taken from the computed value for the square shape.
	# This is also wrong but at least it makes all the shapes rotate at the same speed.
	shape.inertia = 682.66
	add_child(shape)
	current_shape = shape
	shape.connect("body_entered", self, "_on_shape_touched")

func _ready():
	randomize()
	all_time_top = load_score()

func _physics_process(_delta):
	if current_shape:
		current_shape.applied_force = Vector2()
		current_shape.applied_torque = 0
		if Input.is_action_pressed("ui_left"):
			current_shape.applied_force = Vector2(-shape_force, 0)
		if Input.is_action_pressed("ui_right"):
			current_shape.applied_force = Vector2(shape_force, 0)
		if Input.is_action_pressed("ui_up"):
			current_shape.applied_torque = 5000
		var all_shapes = get_tree().get_nodes_in_group("shapes")
		var min_y = $Platform.position.y - top
		for shape in all_shapes:
			if shape != current_shape:
				for owner_id in shape.get_shape_owners():
					var owner_xf = shape.shape_owner_get_transform(owner_id)
					var count = shape.shape_owner_get_shape_count(owner_id)
					for id in range(count):
						var sh = shape.shape_owner_get_shape(owner_id, id)
						for point in sh.points:
							var xformed = shape.transform.xform(owner_xf.xform(point))
							if xformed.y < min_y:
								min_y = xformed.y
		top = round($Platform.position.y - min_y)
		if top > all_time_top:
			print("setting all time top")
			all_time_top = top
		$UI/TopLine.position.y = round($Platform.position.y - top)
		$UI/TopLine/Label.text = str(round(top / 2))
		$UI/AllTimeTopLine.position.y = round($Platform.position.y - all_time_top)
		$UI/AllTimeTopLine/Label.text = str(round(all_time_top / 2))

func _on_shape_touched(_body):
	current_shape.disconnect("body_entered", self, "_on_shape_touched")
	if running:
		call_deferred("drop")


func _on_FailZone_body_entered(body):
	if body.is_in_group("shapes") and running:
		game_over()
	
func game_over():
	running = false
	save_score(all_time_top)
	if current_shape:
		current_shape.disconnect("body_entered", self, "_on_shape_touched")
		current_shape.applied_force = Vector2()
		current_shape = null
	Engine.time_scale = 0.2
	$CanvasModulate.color = Color(1, 0.5, 0.5, 1)
	yield(get_tree().create_timer(1), "timeout")
	Engine.time_scale = 1
	$CanvasModulate.color = Color.white
	get_tree().call_group("shapes", "queue_free")
	yield(get_tree(), "idle_frame")
	$UI/Splash.show()
	
func start():
	$UI/Splash.hide()
	top = -INF
	current_shape = null
	running = true
	call_deferred("drop")
