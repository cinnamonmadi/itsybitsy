extends StaticBody2D

onready var tongue = $tongue
onready var tongue_segment = $tongue/tongue_segment
onready var tongue_tip = $tongue/tongue_tip
onready var tongue_collider = $tongue/collider
onready var tongue_raycast = $raycast
onready var tongue_timer = $timer
onready var sprite = $sprite
onready var eyes = $eyes

const TONGUE_SHOOT_DELAY = 1
const TONGUE_RETRIEVE_DELAY = 1
const MAX_TONGUE_RANGE = 300
const TONGUE_SPEED = 3
const EYE_BASE_POSITION = Vector2(0, -14)
const EYESIGHT_RANGE = 200

export var tongue_range = 0
export var fixed_tongue_range = false
export var face_left = false

var tongue_direction = 1
var facing_direction = 1
var prey = null
var player = null

func _ready():
	tongue.connect("body_entered", self, "_on_tongue_body_entered")

	if face_left:
		sprite.flip_h = true
		tongue_tip.flip_h = true
		tongue_segment.flip_h = true
		tongue.position.x *= -1
		facing_direction = -1
		tongue_collider.rotation_degrees += 180

	tongue_retrieve()

func _process(_delta):
	# Finding the player is done this way so that the scene doesn't crash if for some reason there isn't a player or if the player is lower on the scene tree than a frog
	if player == null:
		player = get_parent().find_node("spider")

	if tongue_timer.is_stopped():
		tongue_collider.shape.length += tongue_direction * TONGUE_SPEED
		if prey != null:
			prey.position.x += facing_direction * tongue_direction * TONGUE_SPEED
			if abs((position.x + tongue.position.x) - prey.position.x) <= 6:
				prey.die()
				prey = null
		if tongue_collider.shape.length >= tongue_range:
			tongue_retrieve()
		elif tongue_collider.shape.length < 0:
			tongue_shoot()
	update_tongue()
	update_eyes()

# Updates the visual components of the tongue
func update_tongue():
	tongue_tip.position = Vector2(facing_direction * tongue_collider.shape.length, 0)
	tongue_segment.region_rect.size.x = tongue_collider.shape.length
	tongue_segment.offset.x = facing_direction * (tongue_collider.shape.length / 2)
	tongue.visible = tongue_collider.shape.length != 0

# Begins a delay after which the tongue will begin retrieving
func tongue_retrieve():
	tongue_collider.shape.length = tongue_range
	tongue_direction *= -1
	tongue_timer.start(TONGUE_RETRIEVE_DELAY)

# Begins a delay after which the tongue will shoot out
func tongue_shoot():
	# If fixed_tongue_range is disabled, raycast to find the spot where the tongue will land
	# (raycasting beforehand leads to more precise collisions with the tilemap and lets most of the code be the same since we reuse the tongue_range variable)
	if not fixed_tongue_range:
		tongue_raycast.cast_to = Vector2(facing_direction * MAX_TONGUE_RANGE, 0)
		tongue_raycast.force_raycast_update()
		if not tongue_raycast.is_colliding():
			tongue_range = MAX_TONGUE_RANGE
		else:
			tongue_range = (position + tongue.position).distance_to(tongue_raycast.get_collision_point())

	tongue_collider.shape.length = 0
	tongue_direction *= -1
	tongue_timer.start(TONGUE_SHOOT_DELAY)

func _on_tongue_body_entered(body):
	if body.get_name() == "spider":
		prey = body
		tongue_direction = -1
		tongue_timer.stop()
		prey.disable()

func update_eyes():
	if player == null or not player.visible:
		return
	eyes.position = EYE_BASE_POSITION
	if player.position.x >= position.x:
		eyes.position.x += 1
	if player.position.y >= position.y:
		eyes.position.y += 1
