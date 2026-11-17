class_name CameraRig
extends Node3D
## Angled strategy camera: pan, zoom, rotate, stays over the map.

var cam: Camera3D
var dist := 68.0
var min_dist := 25.0
var max_dist := 110.0
var pitch := deg_to_rad(46.0)
var yaw := 0.0
var pan_speed := 1.0

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 400.0
	cam.near = 0.5
	add_child(cam)
	cam.current = true
	_apply()

func _apply() -> void:
	rotation = Vector3(0, yaw, 0)
	cam.position = Vector3(0, sin(pitch) * dist, cos(pitch) * dist)
	cam.rotation = Vector3(-pitch, 0, 0)

func look_at_point(p: Vector3) -> void:
	position = Vector3(p.x, 0, p.z)
	_clamp()

func move_by(local: Vector2) -> void:
	## local.x = right, local.y = forward (screen up), in metres
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	position += right * local.x + fwd * local.y
	_clamp()

func zoom_by(f: float) -> void:
	dist = clamp(dist * f, min_dist, max_dist)
	_apply()

func rotate_by(a: float) -> void:
	yaw = wrapf(yaw + a, -PI, PI)
	_apply()

func _clamp() -> void:
	position.x = clamp(position.x, 0.0, Defs.MAP_SIZE)
	position.z = clamp(position.z, 0.0, Defs.MAP_SIZE + 10.0)

## Where a screen point hits the ground (y = 0).
func ground_at(screen: Vector2):
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if abs(d.y) < 0.0001:
		return null
	var t := -o.y / d.y
	if t < 0:
		return null
	return o + d * t

## Pans so that a screen drag of `delta` pixels moves the ground with the finger.
func drag_pan(from: Vector2, to: Vector2) -> void:
	var a = ground_at(from)
	var b = ground_at(to)
	if a == null or b == null:
		return
	var d: Vector3 = a - b
	position += Vector3(d.x, 0, d.z)
	_clamp()
