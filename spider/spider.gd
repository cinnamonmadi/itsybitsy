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
const WEB_RADIUS = 150
const TILE_SIZE = 32

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
	# if web_position != null and position.distance_to(web_position) > WEB_RADIUS:
		# web_position = null
	if web_position == null:
		web.set_point_position(1, Vector2.ZERO)
	else:
		web.set_point_position(1, web_position - position)

func tile_distance(tile_position):
	return pow(tile_position.x - position.x, 2) + pow(tile_position.y - position.y, 2) - pow(WEB_RADIUS, 2)

func nearest_web_tile():
	var nearest_tile = null
	var nearest_tile_dist = -1

	var start = Vector2(floor((position.x - WEB_RADIUS) / TILE_SIZE), floor((position.y - WEB_RADIUS) / TILE_SIZE))
	var end = Vector2(floor((position.x + WEB_RADIUS) / TILE_SIZE), floor((position.y + WEB_RADIUS) / TILE_SIZE))
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			var tile_point = Vector2(x, y)
			var tile_position = tile_point * TILE_SIZE

			var dist_top_left = position.distance_to(tile_position + Vector2(TILE_SIZE, 0))
			var dist_top_right = position.distance_to(tile_position + Vector2(TILE_SIZE, 0))
			var dist_bottom_left = position.distance_to(tile_position + Vector2(0, TILE_SIZE))
			var dist_bottom_right = position.distance_to(tile_position + Vector2(TILE_SIZE, TILE_SIZE))

			var dist_min = min(dist_top_left, min(dist_top_right, min(dist_bottom_left, dist_bottom_right)))

			if dist_min > WEB_RADIUS or tilemap.get_cellv(tile_point) != 1:
				continue

			var tile_center = tile_position + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
			web_raycast.cast_to = tile_center - position
			web_raycast.force_raycast_update()
			var raycast_point = web_raycast.get_collision_point()
			if tile_center.distance_to(raycast_point) > sqrt(2 * pow(TILE_SIZE / 2.0, 2)):
				continue

			if nearest_tile == null or position.distance_to(raycast_point) < nearest_tile_dist:
				nearest_tile = raycast_point
				nearest_tile_dist = position.distance_to(raycast_point)

	return nearest_tile

func websling():
	web_position = nearest_web_tile()
