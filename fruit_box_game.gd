extends Node3D

class_name Game

var fruit_scene = preload("res://fruit.tscn")
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var camera_3d: Camera3D = $game_camera/PitchPivot/Camera3D
@onready var game_camera: Node3D = $game_camera
var target_rotation: float = 0.0
var rotation_speed: float = 3.0  # Adjust speed as necessary
@onready var timer: Timer = $Timer
@onready var area_3d: Area3D = $Area3D 

@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var score_list: RichTextLabel = $CanvasLayer/ScoreList
var is_input_enabled = true

static var fruits = [
	"Cherry", "Strawberry", "Grape", "Dekopon", "Persimmon", "Apple", "Pear", 
	"Peach", "Pineapple", "Melon", "Watermelon"
]

static var colors = [
	Color(0.3, 0, 0), Color(1, 0.2, 0.2), Color(0.2, 0.2, 0.8), 
	Color(0.8, 0.4, 0.2), Color(0.5, 0.2, 0.4), Color(0.9, 0, 0.2), 
	Color(0.6, 0.8, 0.4), Color(1, 0.4, 0.7), Color(1, 0.9, 0), 
	Color(0.2, 0.8, 0.2), Color(0.1, 0.7, 0.1)
]

static var fruit_properties = []

@onready var pointer: MeshInstance3D = $Pointer
@onready var box_container: Node3D = $BoxContainer

var grid_size: Vector2 = Vector2(3, 3)
var grid_spacing: Vector2 = Vector2(0.6, 0.6)
var grid_position: Vector2 = Vector2(0, 0)  # Start in the center of the grid
var target_position: Vector3
var move_speed: float = 10.0
var previous_instance = null
var game_over = false

# Detect screen touch or mouse click to drop a ball
func _input(event):
	if event is InputEventScreenDrag:
		var drag_vector = event.relative
		if drag_vector.x > 20:  # Swipe Right
			target_rotation -= deg_to_rad(90)
		elif drag_vector.x < -20:  # Swipe Left
			target_rotation += deg_to_rad(90)

	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed():
			var click_position = event.position
			var from = camera_3d.project_ray_origin(click_position)
			var to = from + camera_3d.project_ray_normal(click_position) * 1000  # Extend ray far enough

			var space_state = get_world_3d().direct_space_state
			var ray_params = PhysicsRayQueryParameters3D.new()
			ray_params.from = from
			ray_params.to = to
			ray_params.collision_mask = 1  # Optional: specify a collision mask, if necessary

			var result = space_state.intersect_ray(ray_params)

			if result:
				var hit_position = result.position

				# Convert the hit position to grid coordinates and clamp within grid boundaries
				grid_position.x = clamp(int(hit_position.x / grid_spacing.x), -1, 1)
				grid_position.y = clamp(int(hit_position.z / grid_spacing.y), -1, 1)

				# Compute the new world position based on the clamped grid position
				var new_x = grid_position.x * grid_spacing.x
				var new_z = grid_position.y * grid_spacing.y
				target_position = Vector3(new_x, pointer.transform.origin.y, new_z)
				if previous_instance.has_landed: 
					previous_instance.position = target_position
		

					
func is_point_in_grid(point: Vector3) -> bool:
	# Ensure the point clicked is within the grid boundaries
	var grid_x = int(point.x / grid_spacing.x)
	var grid_z = int(point.z / grid_spacing.y)
	return abs(grid_x) < grid_size.x and abs(grid_z) < grid_size.y

func create_fruit_properties():
	for i in range(fruits.size()):
		var fruit_dict = {
			"name": fruits[i],
			"radius": 0.1 + i * 0.05, 
			"color": colors[i],
			"value": i * 2 + 2
		}
		fruit_properties.append(fruit_dict)

func _move_pointer() -> void:
	# Handle camera rotation
	if Input.is_action_just_released("rotate_left"):
		target_rotation += deg_to_rad(90)
	if Input.is_action_just_released("rotate_right"):
		target_rotation -= deg_to_rad(90)

	var camera_rotation = wrapf(game_camera.rotation.y, 0, 2 * PI)
	var direction_vector = Vector2()
	if Input.is_action_just_released("move_forward"):
		direction_vector.y -= 1
	if Input.is_action_just_released("move_backward"):
		direction_vector.y += 1
	if Input.is_action_just_released("move_left"):
		direction_vector.x -= 1
	if Input.is_action_just_released("move_right"):
		direction_vector.x += 1

	var adjusted_direction = direction_vector.rotated(-camera_rotation)
	grid_position.x += adjusted_direction.x
	grid_position.y += adjusted_direction.y

	grid_position.x = clamp(grid_position.x, -1, 1)
	grid_position.y = clamp(grid_position.y, -1, 1)

	var new_x = grid_position.x * grid_spacing.x
	var new_z = grid_position.y * grid_spacing.y
	target_position = Vector3(new_x, pointer.transform.origin.y, new_z)

func _create_fruit() -> Fruit:
	var fruit_property = fruit_properties.slice(0, 5).pick_random()
	var fruit_instance = fruit_scene.instantiate()
	if not fruit_instance:
		return
	fruit_instance.game = self
	fruit_instance.fruit_property = fruit_property
	
	var new_shape = SphereShape3D.new()
	new_shape.radius = fruit_property.radius
	fruit_instance.get_node("CollisionShape3D").shape = new_shape
	
	var csgsphere = fruit_instance.get_node("CSGSphere3D")
	csgsphere.radius = fruit_property.radius

	var new_material = StandardMaterial3D.new()
	new_material.albedo_color = fruit_property.color
	new_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	new_material.roughness = 0.0

	csgsphere.material = new_material
	fruit_instance.position = pointer.position
	fruit_instance.freeze = true
	add_child(fruit_instance)
	return fruit_instance

func _ready() -> void:
	create_fruit_properties()
	target_position = pointer.transform.origin

func _process(delta: float) -> void:
	if not Main.game_over:
		score_label.text = str(Main.score)
	
	_move_pointer()
	pointer.transform.origin = pointer.transform.origin.lerp(target_position, move_speed * delta)
	if is_input_enabled:
		game_camera.rotation.y = lerp(game_camera.rotation.y, target_rotation, delta * rotation_speed)

	if is_instance_valid(previous_instance) and is_input_enabled:
		if previous_instance.is_freeze_enabled():
			previous_instance.position = pointer.position
		if Input.is_action_just_released("action"):
			previous_instance.freeze = false
	
	if (not previous_instance or previous_instance.has_landed) and not game_over:
		previous_instance = _create_fruit()

	if Main.game_over:
		Engine.time_scale = 0.1
		if Input.is_action_just_released("action") and is_input_enabled:
			Main.game_over = false
			Main.score = 0
			Engine.time_scale = 1
			area_3d.monitoring = true
			get_parent().get_tree().reload_current_scene()

func _on_timer_timeout() -> void:
	is_input_enabled = true

func _on_area_3d_body_shape_exited(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int) -> void:
	if not Main.game_over:
		if body is Fruit and body.position.y >= 2:
			is_input_enabled = false
			Main.game_over = true
			area_3d.monitoring = false
			if Main.score != 0:
				if Main.score_list.max() and Main.score_list.max() < Main.score: 
					score_label.text = "New High Score! " + str(Main.score)
					Audio.play("res://soundfx/coin")
				else: 
					score_label.text = "Score " + str(Main.score)
				Main.score_list.append(Main.score)
				Main.score_list.sort()
				Main.score_list.reverse()
			else: 
				score_label.text = "Try Again"
			timer.start()
