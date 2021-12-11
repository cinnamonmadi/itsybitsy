extends KinematicBody2D

onready var sprite = $sprite
onready var jump_input_timer = $jump_input_timer
onready var coyote_timer = $coyote_timer
onready var web = $web
onready var web_raycast = $web_raycast
onready var tilemap = get_parent().find_node("tilemap")

const SPEED = 150
const GRAVITY = 6
const MAX_SWING_SPEED = 200
const MAX_FALL_SPEED = 300
const JUMP_IMPULSE = 200
const JUMP_INPUT_DURATION = 0.06
const COYOTE_TIME_DURATION = 0.06
const WEB_RADIUS = 150
const WEB_IMPULSE_SPEED = 5
const WEB_CLIMB_SPEED = 30
const TILE_SIZE = 32

var v_direction = 0
var direction = Vector2.ZERO
var grounded = false
var velocity = Vector2.ZERO
var web_position = null
var swing_speed = 0
var wall_climb_direction = 0
var ceiling_climbing = false

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
		direction.x = -1
	if Input.is_action_just_pressed("right"):
		direction.x = 1
	if Input.is_action_just_released("left"):
		if Input.is_action_pressed("right"):
			direction.x = 1
		else:
			direction.x = 0
	if Input.is_action_just_released("right"):
		if Input.is_action_pressed("left"):
			direction.x = -1
		else:
			direction.x = 0
	if Input.is_action_just_pressed("up"):
		direction.y = -1
	if Input.is_action_just_pressed("down"):
		direction.y = 1
	if Input.is_action_just_released("up"):
		if Input.is_action_pressed("down"):
			direction.y = 1
		else:
			direction.y = 0
	if Input.is_action_just_released("down"):
		if Input.is_action_pressed("up"):
			direction.y = -1
		else:
			direction.y = 0
	if Input.is_action_just_pressed("jump"):
		jump_input_timer.start(JUMP_INPUT_DURATION)
	if Input.is_action_just_pressed("web"):
		web_sling()
	if Input.is_action_just_released("web"):
		web_release()

func move():
	if not grounded and wall_climb_direction == 0 and not ceiling_climbing and web_position != null:
		# Web pulls player towards the bottom
		var web_pull_direction = 0
		if web_position.x - position.x > 5:
			web_pull_direction = 1
		elif web_position.x - position.x < 5:
			web_pull_direction = -1
		swing_speed += web_pull_direction * 5

		# Player input swings web left and right
		if position.y > web_position.y:
			swing_speed += direction.x * WEB_IMPULSE_SPEED

		# Gradual drag
		swing_speed *= 0.99

		# Limit the swing speed
		if swing_speed > MAX_SWING_SPEED:
			swing_speed = MAX_SWING_SPEED

		# Set velocity based on the swing direction
		var swing_direction = 0
		if swing_speed > 0:
			swing_direction = 1
		elif swing_speed < 0:
			swing_direction = -1
		if swing_direction == 0:
			velocity = Vector2.ZERO
		else:
			velocity = (web_position - position).normalized().rotated(swing_direction * PI / 2) * abs(swing_speed)

		# Player input climbs them up or down the web
		if direction.y != 0:
			var climb_vector = (web_position - position).normalized()
			if direction.y == 1:
				climb_vector = climb_vector.rotated(PI)
			velocity += climb_vector * WEB_CLIMB_SPEED
	else:
		if ceiling_climbing: # Ceiling climbing
			velocity.x = direction.x * SPEED
			velocity.y = -5
		elif wall_climb_direction != 0: # Wall climbing
			velocity.x = wall_climb_direction * 5
			velocity.y = direction.y * SPEED
		elif grounded and direction.y == 1: # Crouching
			velocity.x = 0
		elif grounded: # Floor walking
			velocity.x = direction.x * SPEED
		else: # Mid-air motion with drag
			velocity.x += direction.x * 30
			if velocity.x > SPEED:
				velocity.x = SPEED
			elif velocity.x < -SPEED:
				velocity.x = -SPEED
			velocity.x *= 0.99
		if wall_climb_direction == 0 and not ceiling_climbing:
			velocity.y += GRAVITY

	var was_grounded = grounded
	grounded = is_on_floor()
	if grounded:
		wall_climb_direction = 0
	if was_grounded and not grounded:
		coyote_timer.start(COYOTE_TIME_DURATION)
	if (grounded or not coyote_timer.is_stopped() or wall_climb_direction != 0 or ceiling_climbing) and not jump_input_timer.is_stopped():
		jump_input_timer.stop()
		jump()
	if grounded and velocity.y >= 5:
		velocity.y = 5
	if velocity.y > MAX_FALL_SPEED:
		velocity.y = MAX_FALL_SPEED

	var _linear_velocity = move_and_slide(velocity, Vector2(0, -1))

	# Check to see if we are wall climbing
	wall_climb_direction = 0
	if velocity.x != 0 and not grounded and not ceiling_climbing:
		for i in get_slide_count():
			var wall_position = position + (Vector2(velocity.x, 0).normalized() * (float(TILE_SIZE) / 2))
			var wall_tile = tilemap.world_to_map(wall_position)
			if tilemap.get_cellv(wall_tile) == 1:
				wall_climb_direction = Vector2(velocity.x, 0).normalized().x
				break
	ceiling_climbing = false
	if wall_climb_direction == 0 and velocity.y < 0:
		for i in get_slide_count():
			var ceiling_position = position + (Vector2(0, velocity.y).normalized() * (float(TILE_SIZE) / 2))
			var ceiling_tile = tilemap.world_to_map(ceiling_position)
			if tilemap.get_cellv(ceiling_tile) == 1:
				ceiling_climbing = true
				break

func jump():
	velocity.y = -JUMP_IMPULSE
	grounded = false
	if ceiling_climbing:
		velocity.y *= -1
		ceiling_climbing = false
	if wall_climb_direction != 0:
		velocity.x = JUMP_IMPULSE * wall_climb_direction * -1
		wall_climb_direction = 0

func update_sprite():
	if grounded and direction.y == 1:
		sprite.play("crouch")
	elif (direction.x == 0 and (grounded or ceiling_climbing)) or (direction.y == 0 and wall_climb_direction != 0):
		sprite.play("idle")
	elif (direction.x != 0 and (grounded or ceiling_climbing)) or (direction.y != 0 and wall_climb_direction != 0):
		sprite.play("run")
	elif not grounded and (web_position != null or velocity.y > 0):
		sprite.play("fall")
	elif not grounded and abs(velocity.y) < 25 and web_position == null:
		sprite.play("jump_peak")
	elif not grounded and velocity.y < 0 and web_position == null:
		sprite.play("jump")

	if ceiling_climbing:
		sprite.rotation_degrees = 180
	else:
		sprite.rotation_degrees = wall_climb_direction * -90
	if ceiling_climbing:
		sprite.offset.y = -1
		if (direction.x == -1 and sprite.flip_h) or (direction.x == 1 and not sprite.flip_h):
			sprite.flip_h = not sprite.flip_h
	elif wall_climb_direction == 0:
		sprite.offset.y = 0
		if (direction.x == 1 and sprite.flip_h) or (direction.x == -1 and not sprite.flip_h):
			sprite.flip_h = not sprite.flip_h
	elif wall_climb_direction == -1:
		sprite.offset.y = 3
		if (direction.y == 1 and sprite.flip_h) or (direction.y == -1 and not sprite.flip_h):
			sprite.flip_h = not sprite.flip_h
	elif wall_climb_direction == 1:
		sprite.offset.y = 4
		if (direction.y == -1 and sprite.flip_h) or (direction.y == 1 and not sprite.flip_h):
			sprite.flip_h = not sprite.flip_h

func update_web():
	if web_position == null:
		web.set_point_position(1, Vector2.ZERO)
	else:
		if check_web_collision():
			web_position = null
		else:
			web.set_point_position(1, web_position - position)

func check_web_collision():
	var STEP = 8
	var web_direction = (web_position - position).normalized()
	var check_point = position + (web_direction * STEP)
	while check_point.distance_to(web_position) > STEP:
		if tilemap.get_cellv(tilemap.world_to_map(check_point)) != -1:
			print("player tile: ", tilemap.world_to_map(position), " vs failed pos: ", tilemap.world_to_map(check_point), " vs web tile: ", tilemap.world_to_map(web_position))
			return true
		check_point += (web_direction * STEP)
	return false

func tile_distance(tile_position):
	return pow(tile_position.x - position.x, 2) + pow(tile_position.y - position.y, 2) - pow(WEB_RADIUS, 2)

func nearest_web_tile():
	var nearest_tile = null
	var nearest_tile_dist = -1

	var aim_direction = velocity.normalized()
	if aim_direction.y > 0:
		aim_direction.y = 0
	aim_direction += direction
	var position_offset = position + (aim_direction.normalized() * (TILE_SIZE * 1.5))

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

			if nearest_tile == null or position_offset.distance_to(raycast_point) < nearest_tile_dist:
				nearest_tile = raycast_point
				nearest_tile_dist = position_offset.distance_to(raycast_point)

	return nearest_tile

func web_sling():
	web_position = nearest_web_tile()
	if web_position != null:
		swing_speed = velocity.length()
		if position.x - web_position.x > 5:
			swing_speed *= -1

func web_release():
	web_position = null
