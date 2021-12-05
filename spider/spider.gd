extends KinematicBody2D

onready var sprite = $sprite
onready var jump_input_timer = $jump_input_timer
onready var coyote_timer = $coyote_timer
onready var web = $web
onready var web_raycast = $web_raycast
onready var tilemap = get_parent().find_node("tilemap")

const SPEED = 100
const GRAVITY = 3
const MAX_FALL_SPEED = 150
const JUMP_IMPULSE = 200
const JUMP_INPUT_DURATION = 0.06
const COYOTE_TIME_DURATION = 0.06
const WEB_RADIUS = 300

var direction = 0
var grounded = false
var velocity = Vector2.ZERO
var web_position = null

func _ready():
	web.add_point(Vector2.ZERO)
	web.add_point(Vector2.ZERO)

func _physics_process(_delta):
	handle_input()
	move()
	update_web()
	update_sprite()

func handle_input():
	if Input.is_action_just_pressed("left"):
		direction = -1
	if Input.is_action_just_pressed("right"):
		direction = 1
	if Input.is_action_just_released("left"):
		if Input.is_action_pressed("right"):
			direction = 1
		else:
			direction = 0
	if Input.is_action_just_released("right"):
		if Input.is_action_pressed("left"):
			direction = -1
		else:
			direction = 0
	if Input.is_action_just_pressed("jump"):
		jump_input_timer.start(JUMP_INPUT_DURATION)
	if Input.is_action_just_pressed("web"):
		websling()

func move():
	velocity.x = direction * SPEED
	velocity.y += GRAVITY

	var was_grounded = grounded
	grounded = is_on_floor()
	if was_grounded and not grounded:
		coyote_timer.start(COYOTE_TIME_DURATION)
	if (grounded or not coyote_timer.is_stopped()) and not jump_input_timer.is_stopped():
		jump_input_timer.stop()
		jump()
	if grounded and velocity.y >= 5:
		velocity.y = 5
	if velocity.y > MAX_FALL_SPEED:
		velocity.y = MAX_FALL_SPEED

	var _collisions = move_and_slide(velocity, Vector2(0, -1))

func jump():
	self.velocity.y = -JUMP_IMPULSE
	grounded = false

func update_sprite():
	sprite.play("idle")
	if (direction == -1 and sprite.flip_h) or (direction == 1 and not sprite.flip_h):
		sprite.flip_h = not sprite.flip_h

func update_web():
	if web_position != null and position.distance_to(web_position) > ((WEB_SEARCH_RADIUS + 1) * 32):
		web_position = null
	if web_position == null:
		web.set_point_position(1, Vector2.ZERO)
	else:
		web.set_point_position(1, web_position - position)

func nearest_web_tile():
	var player_coordinates = tilemap.world_to_map(position)
	var nearest_point = null

	for search_radius in range(0, WEB_SEARCH_RADIUS + 1):
		print(search_radius)
		var start = player_coordinates - Vector2(search_radius, search_radius)
		var end = player_coordinates + Vector2(search_radius, search_radius)
		var search_points = []

		for x in range(start.x, end.x + 1):
			search_points.append(Vector2(x, start.y))
			search_points.append(Vector2(x, end.y))
		for y in range(start.y + 1, end.y):
			search_points.append(Vector2(start.x, y))
			search_points.append(Vector2(end.x, y))

		for point in search_points:
			if tilemap.get_cellv(point) == 1:
				return tilemap.map_to_world(point)
	return null

func websling():
	web_position = null
	var nearest_tile = nearest_web_tile()
	if nearest_tile != null:
		web_raycast.cast_to = (nearest_tile - position) + Vector2(16, 16)
		web_raycast.force_raycast_update()
		var collision = web_raycast.get_collider()
		if collision == tilemap:
