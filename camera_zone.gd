extends Area2D

func _ready():
	var _unused_return_value = connect("body_entered", self, "_on_body_entered")
	_unused_return_value = connect("body_exited", self, "_on_body_exited")

func _on_body_entered(body):
	if body.get_name() == "spider":
		body.camera_enter_zone(position)

func _on_body_exited(body):
	if body.get_name() == "spider":
		body.camera_exit_zone()
