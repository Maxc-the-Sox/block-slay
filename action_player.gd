extends CharacterBody2D

var max_hp = 10
var hp = 10

const SPEED = 150.0

@onready var anim = $AnimatedSprite2D 
var last_direction = "down" 

var target_position = Vector2.ZERO
var is_moving_to_click = false
var is_attacking = false 
var is_dead = false # Unser neuer Schalter für das Game Over!

func _ready():
	anim.animation_finished.connect(_on_animation_finished)

func _input(event):
	# Wenn wir tot sind oder angreifen, ignorieren wir alle Klicks!
	if is_dead or is_attacking:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		
		# Prüfen, ob wir auf ein Monster geklickt haben
		var ziel_ist_monster = false
		var alle_monster = get_tree().get_nodes_in_group("Enemies")
		for enemy in alle_monster:
			if is_instance_valid(enemy) and not enemy.is_dead and enemy.is_active:
				# Wenn die Maus sehr nah am Monster ist (z.B. 20 Pixel)
				if mouse_pos.distance_to(enemy.global_position) < 20.0:
					ziel_ist_monster = true
					break
					
		# Wenn wir ein Monster angeklickt haben ODER Shift halten -> Angriff!
		if ziel_ist_monster or Input.is_key_pressed(KEY_SHIFT):
			_starte_angriff(mouse_pos)
		else:
			# Normaler Klick auf leeren Boden -> Laufen!
			target_position = mouse_pos
			is_moving_to_click = true

	elif event.is_action_pressed("attack") and not event is InputEventMouseButton:
		var aim = global_position
		if last_direction == "right": aim.x += 10
		elif last_direction == "left": aim.x -= 10
		elif last_direction == "down": aim.y += 10
		elif last_direction == "up": aim.y -= 10
		_starte_angriff(aim)

func _starte_angriff(ziel_position: Vector2):
	is_attacking = true
	is_moving_to_click = false 
	velocity = Vector2.ZERO
	
	var attack_dir = global_position.direction_to(ziel_position)
	if abs(attack_dir.x) > abs(attack_dir.y):
		last_direction = "right" if attack_dir.x > 0 else "left"
	else:
		last_direction = "down" if attack_dir.y > 0 else "up"
		
	anim.play("attack_" + last_direction)
	_deal_damage_to_enemies() # Löst den physischen Schaden aus!

func _physics_process(_delta):
	# ---> WICHTIG: Leichen bewegen sich nicht! <---
	if is_dead: 
		return
		
	if is_attacking:
		move_and_slide() 
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_key_pressed(KEY_SHIFT):
		target_position = get_global_mouse_position()
		is_moving_to_click = true

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_direction = Vector2.ZERO 
	
	if input_dir != Vector2.ZERO:
		is_moving_to_click = false
		move_direction = input_dir
		velocity = move_direction * SPEED
	elif is_moving_to_click:
		if global_position.distance_to(target_position) > 5.0:
			move_direction = global_position.direction_to(target_position)
			velocity = move_direction * SPEED
		else:
			velocity = Vector2.ZERO
			is_moving_to_click = false
	else:
		velocity = Vector2.ZERO

	if velocity != Vector2.ZERO:
		if abs(move_direction.x) > abs(move_direction.y):
			last_direction = "right" if move_direction.x > 0 else "left"
		else:
			last_direction = "down" if move_direction.y > 0 else "up"
		anim.play("walk_" + last_direction)
	else:
		anim.play("idle_" + last_direction)

	move_and_slide()

func _deal_damage_to_enemies():
	# Wir warten kurz, bis das Schwert optisch wirklich zuschlägt
	await get_tree().create_timer(0.2).timeout
	
	# --- SICHERHEITS-CHECK ---
	# Prüfen, ob der Spieler noch in der Welt ist (verhindert den get_tree() Fehler)
	if not is_inside_tree() or is_dead:
		return
	
	var tree = get_tree()
	if tree == null: return
	
	var alle_monster = tree.get_nodes_in_group("Enemies")
	for enemy in alle_monster:
		# Prüfen, ob das Monster überhaupt noch existiert
		if not is_instance_valid(enemy) or enemy.is_dead or not enemy.is_active: 
			continue
		
		# Prüfen, ob das Monster nah genug ist (40 Pixel Reichweite)
		if global_position.distance_to(enemy.global_position) <= 40.0:
			var dir_to_enemy = global_position.direction_to(enemy.global_position)
			var hit = false
			
			# Trifft der Spieler in die Richtung, in die er gerade schaut?
			if last_direction == "right" and dir_to_enemy.x > 0.3: hit = true
			elif last_direction == "left" and dir_to_enemy.x < -0.3: hit = true
			elif last_direction == "down" and dir_to_enemy.y > 0.3: hit = true
			elif last_direction == "up" and dir_to_enemy.y < -0.3: hit = true
			
			if hit:
				enemy.take_damage(1) # Ork/Slime verliert 1 HP

func take_damage(amount: int):
	if is_dead: return
	hp -= amount
	
	# Rotes Aufblitzen
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# Dem UI Bescheid sagen, dass wir Herzen verloren haben!
	var current_scene = get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene.has_node("UI"):
		current_scene.get_node("UI").update_health(hp, max_hp)
	
	# ---> DIE ECHTE TODES-SEQUENZ <---
	if hp <= 0:
		is_dead = true
		velocity = Vector2.ZERO
		print("GAME OVER - Spieler ist tot!")
		
		# Spiele die Todesanimation, falls der Spieler eine hat
		if anim.sprite_frames.has_animation("die"):
			anim.play("die")
			await anim.animation_finished
			
		# Startet das Dungeon-Level nach dem Tod einfach neu
		get_tree().reload_current_scene()

func _on_animation_finished():
	if anim.animation.begins_with("attack_"):
		is_attacking = false
