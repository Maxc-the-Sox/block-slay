extends CharacterBody2D

var max_hp = 10
var hp = 10

const SPEED = 150.0

@onready var anim = $AnimatedSprite2D # Achte darauf, dass der Node genau so heißt!
var last_direction = "down" # Merkt sich, wohin wir zuletzt geschaut haben

func _physics_process(_delta):
	# 1. Richtung holen
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	
	# 2. Herauskriegen, wohin wir genau schauen (Nur 4 Richtungen, keine Diagonalen)
	if direction != Vector2.ZERO:
		if abs(direction.x) > abs(direction.y):
			last_direction = "right" if direction.x > 0 else "left"
		else:
			last_direction = "down" if direction.y > 0 else "up"
			
		# Wenn wir uns bewegen, spiele die Lauf-Animation
		anim.play("walk_" + last_direction)
	else:
		# Wenn wir stehen, spiele die Idle-Animation in die letzte Richtung
		anim.play("idle_" + last_direction)

	# 3. Bewegen
	move_and_slide()
