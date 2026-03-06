extends CharacterBody2D

@export var max_hp: int = 3
@export var speed: float = 60.0
@export var attack_damage: int = 1
@export var attack_range: float = 25.0 # Wie nah muss er ran, um zuzuhauen?

var current_hp: int
var player: Node2D = null
var last_direction: String = "down"

# Zustände des Monsters
var is_attacking: bool = false
var is_dead: bool = false
var is_active: bool = false # NEU: Das Monster schläft am Anfang!

@onready var anim = $AnimatedSprite2D

func _ready():
	current_hp = max_hp
	visible = false # Versteckt im Nebel
	
	if anim:
		anim.animation_finished.connect(_on_animation_finished)
	
	player = get_tree().get_first_node_in_group("Player")
	add_to_group("Enemies") # Gibt dem Monster automatisch sein Namensschild!

# NEU: Wird vom Dungeon gerufen, wenn das Licht angeht!
func wake_up():
	if is_dead: return
	is_active = true
	visible = true

func _physics_process(_delta):
	# Wenn tot, schläft, greift an, oder kein Spieler da -> stehen bleiben
	if is_dead or is_attacking or player == null or not is_active:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance <= attack_range:
		_attack()
	else:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		move_and_slide()
		
		_update_direction_string(direction)
		
		# SICHERER ANIMATIONS-AUFRUF FÜR LAUFEN
		var anim_name = "walk_" + last_direction
		if anim.sprite_frames.has_animation(anim_name):
			anim.play(anim_name)
		elif anim.sprite_frames.has_animation("walk"):
			anim.play("walk")

func _attack():
	is_attacking = true
	velocity = Vector2.ZERO # Beim Schlagen stehen bleiben
	
	# ---> NEU: SOUND FÜR DEN ANGRIFF <---
	if has_node("SfxAttack"):
		$SfxAttack.play()
	
	var direction = global_position.direction_to(player.global_position)
	_update_direction_string(direction)
	
	# SICHERER ANIMATIONS-AUFRUF FÜR ANGRIFF
	var anim_name = "attack_" + last_direction
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
	elif anim.sprite_frames.has_animation("attack"):
		anim.play("attack")
	
	# NEU: Wir warten 0.3 Sekunden, damit der Schaden genau beim Schwertschwung passiert!
	await get_tree().create_timer(0.3).timeout
	if not is_dead and is_instance_valid(player):
		# Prüfen, ob der Spieler noch nah genug ist (könnte ja weggelaufen sein)
		if global_position.distance_to(player.global_position) <= attack_range + 10:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)

func take_damage(amount: int):
	if is_dead: return
	
	current_hp -= amount
	
	# ---> NEU: SOUND FÜR DEN SCHMERZ <---
	if has_node("SfxHurt"):
		$SfxHurt.play()
	
	# NEU: Rotes Blinken als Treffer-Feedback!
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	if current_hp <= 0:
		die()

func die():
	is_dead = true
	is_active = false
	velocity = Vector2.ZERO
	
	# ---> NEU: SOUND FÜR DAS STERBEN <---
	if has_node("SfxDeath"):
		$SfxDeath.play()
	
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	# --- NEU: RICHTUNG BASIEREND AUF SPIELER-POSITION ---
	var animation_zu_spielen = "die_front"
	
	if is_instance_valid(player):
		var richtung_vom_spieler = player.global_position.direction_to(global_position)
		
		# Wir schauen, ob der Schlag eher von oben/unten oder links/rechts kam
		if abs(richtung_vom_spieler.x) > abs(richtung_vom_spieler.y):
			# Seitlicher Schlag
			animation_zu_spielen = "die_front"
			# Wenn der Spieler links von mir steht (x > 0), falle ich nach RECHTS (nicht gespiegelt)
			# Wenn der Spieler rechts von mir steht (x < 0), falle ich nach LINKS (gespiegelt)
			anim.flip_h = richtung_vom_spieler.x < 0
		else:
			# Schlag von oben oder unten
			if richtung_vom_spieler.y < 0:
				# Spieler steht unter mir -> Ich falle nach oben (hinten) weg
				animation_zu_spielen = "die_back"
			else:
				# Spieler steht über mir -> Ich falle nach unten (vorne) weg
				animation_zu_spielen = "die_front"

	# --- AUSFÜHRUNG ---
	if anim.sprite_frames.has_animation(animation_zu_spielen):
		anim.play(animation_zu_spielen)
	elif anim.sprite_frames.has_animation("die"):
		anim.play("die")
	else:
		queue_free()

func _update_direction_string(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		last_direction = "right" if direction.x > 0 else "left"
	else:
		last_direction = "down" if direction.y > 0 else "up"

func _on_animation_finished():
	# WICHTIG: Hier den Unterstrich weggelassen, damit er "attack" und "attack_left" erkennt!
	if anim.animation.begins_with("attack"):
		is_attacking = false 
	elif anim.animation.begins_with("die"):
		# Warte 3 Sekunden, bevor die Leiche gelöscht wird
		await get_tree().create_timer(3.0).timeout
		
		# Optional: Die Leiche langsam durchsichtig machen (Faden)
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		await tween.finished
		
		queue_free()


func _on_idle_timer_timeout():
	if not is_dead and is_active:
		if has_node("SfxIdle"):
			$SfxIdle.play()
		# Timer auf eine neue zufällige Zeit stellen (zwischen 3 und 8 Sekunden), 
		# damit sie nicht wie Roboter alle im selben Takt grunzen!
		$IdleTimer.wait_time = randf_range(3.0, 8.0)
