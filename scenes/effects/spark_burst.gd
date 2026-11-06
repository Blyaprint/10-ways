extends Node2D

var sparks: Array[Dictionary] = []

const SPARK_COUNT := 0
const GRAVITY := Vector2(0, 420.0)


func _ready() -> void:
	z_index = 3000
	create_sparks()
	


func create_sparks() -> void:
	for i in range(SPARK_COUNT):
		var angle := randf_range(0.0, TAU)
		var direction := Vector2.RIGHT.rotated(angle)
		var speed := randf_range(1220.0, 1620.0)
		var lifetime := randf_range(0.25, 0.65)

		sparks.append({
			"position": Vector2.ZERO,
			"velocity": direction * speed,
			"life": lifetime,
			"max_life": lifetime,
			"width": randf_range(0.5, 0.9),
			"length": randf_range(50.0, 145.0)
		})


func _process(delta: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		var spark: Dictionary = sparks[i]

		spark["position"] += spark["velocity"] * delta
		spark["velocity"] += GRAVITY * delta
		spark["velocity"] *= pow(0.35, delta)

		spark["life"] -= delta

		if spark["life"] <= 0.0:
			sparks.remove_at(i)
		else:
			sparks[i] = spark

	queue_redraw()

	if sparks.is_empty():
		queue_free()


func _draw() -> void:
	for spark in sparks:
		var velocity: Vector2 = spark["velocity"]
		var direction := velocity.normalized()

		if direction.length_squared() < 0.001:
			continue

		var head: Vector2 = spark["position"]
		var length := float(spark["length"])
		var tail: Vector2 = head - direction * length

		var side := direction.orthogonal()
		var bend := randf_range(-5.0, 5.0)

		var middle := (head + tail) / 2.0 + side * bend

		var points := PackedVector2Array([
			tail,
			(tail + middle) / 2.0,
			middle,
			(middle + head) / 2.0,
			head
		])

		var alpha: float = clampf(
			spark["life"] / spark["max_life"],
			0.0,
			1.0
		)

		var glow := Color(1.0, 0.35, 0.05, alpha * 0.25)
		var orange := Color(1.0, 0.48, 0.08, alpha)
		var core := Color(1.0, 0.92, 0.62, alpha)

		var width: float = float(spark["width"])

		draw_polyline(points, glow, width * 3.5, true)
		draw_polyline(points, orange, width, true)
		draw_circle(head, width * 0.65, core)
