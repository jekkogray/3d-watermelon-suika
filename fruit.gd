class_name Fruit
extends RigidBody3D

@onready var csg_sphere_3d: CSGSphere3D = $CSGSphere3D
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var cpu_particles_3d: CPUParticles3D = $CPUParticles3D

var fruit_property = null
var game: Game = null
var has_landed = false
var fx_duration = 2
var audio_stream_player_2d:AudioStreamPlayer = AudioStreamPlayer.new()
@onready var timer: Timer = $Timer

func _ready() -> void: 
	# Start the timer
	var timer = Timer.new()
	timer.wait_time = fx_duration
	timer.one_shot = true
	timer.connect("timeout", _on_timer_timeout) 
	add_child(timer)
	timer.start()
	
# Called when the timer times out 
func _on_timer_timeout() -> void:
	# Stop the action after 2 seconds
	cpu_particles_3d.emitting = false

func set_radius(radius: float) -> void:
	csg_sphere_3d.radius = radius
	collision_shape_3d.shape.radius = radius
	
func _on_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if !has_landed: 
		Audio.play("res://soundfx/land.ogg")
		
	has_landed = true
	
	if body is Fruit: 
		if fruit_property.name == body.fruit_property.name:   
			print("self fruit_type: ", fruit_property.name, " body fruit_type: ", body.fruit_property.name)                                                                                                                                                                
			print("Collided with: ", body.get_instance_id())

			# Ensure only one object handles the spawning by comparing their instance IDs
			if get_instance_id() < body.get_instance_id() and not Main.game_over:  # Only one will execute this
				# Calculate the midpoint_position between the two objects
				var position_a = global_transform.origin
				var position_b = body.global_transform.origin
				var midpoint_position = (position_a + position_b) / 2.0
				
				# Instantiate the new object (fruit) at the midpoint_position
				var fruit_instance = game.fruit_scene.instantiate()
				
				# update to the next fruit type
				var next_index = clamp(game.fruit_properties.find(fruit_property) + 1, 0, game.fruit_properties.size()-1)
				var next_fruit_property = game.fruit_properties[next_index]
				fruit_instance.fruit_property = next_fruit_property
						
				# initialize properties
				fruit_instance.game = game
				fruit_instance.position = midpoint_position
						
				# Set radius of fruit collision
				var new_shape = SphereShape3D.new()
				if not new_shape: 
					print("Failed to create new collision shape.")
					return
					
				new_shape.radius = fruit_instance.fruit_property.radius
				fruit_instance.get_node("CollisionShape3D").shape = new_shape
				
				# Set sphere radius
				var csgsphere = fruit_instance.get_node("CSGSphere3D")
				if not csgsphere: 
					print("Failed to get CSGSphere3D.")
					return

				csgsphere.radius = fruit_instance.fruit_property.radius
				
				# Set new material
				var new_material = StandardMaterial3D.new()
				
				if not new_material: 
					print("Failed to create new material.")
					return
					
				new_material.albedo_color = fruit_instance.fruit_property.color
				new_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				new_material.roughness = 0
			
				csgsphere.material = new_material
				get_parent().add_child(fruit_instance)
				fruit_instance.cpu_particles_3d.emitting = true

			
				Main.score += fruit_instance.fruit_property.value
		
				# Play collision sound
				Audio.play("res://soundfx/water-drop.mp3")
				
				# Destroy both objects
				body.queue_free()
				queue_free()
				
