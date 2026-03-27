extends CharacterBody2D

var max_hp = 10
var hp = 10

const SPEED = 150.0
const ATTACK_RANGE = 25.0 # Wie nah muss der Spieler ran?

@onready var anim = $AnimatedSprite2D 
var last_direction = "down" 

var target_position = Vector2.ZERO
var is_moving_to_click = false
var is_attacking = false 
var is_dead = false 

var target_enemy: Node2D = null 
var is_holding_mouse = false

func _ready():
	# ---> NEU: HP aus dem Rucksack holen! <---
	hp = GlobalData.player_hp
	max_hp = GlobalData.player_max_hp
	
	anim.animation_finished.connect(_on_animation_finished)

func _unhandled_input(event):
	if is_dead or is_attacking:
		return

	# NEU: Wir prüfen hier nur, OB es die linke Maus ist (egal ob gedrückt oder losgelassen)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Taste WURDE GEDRÜCKT (und das UI war nicht im Weg!)
			is_holding_mouse = true
			
			var mouse_pos = get_global_mouse_position()
			var clicked_enemy = null
			var alle_monster = get_tree().get_nodes_in_group("Enemies")
			for enemy in alle_monster:
				if is_instance_valid(enemy) and not enemy.is_dead and enemy.is_active:
					if mouse_pos.distance_to(enemy.global_position) < 20.0:
						clicked_enemy = enemy
						break
						
			if clicked_enemy:
				if Input.is_key_pressed(KEY_SHIFT):
					target_enemy = null
					_starte_angriff(mouse_pos)
				else:
					target_enemy = clicked_enemy
					is_moving_to_click = false 
			elif Input.is_key_pressed(KEY_SHIFT):
				target_enemy = null
				_starte_angriff(mouse_pos)
			else:
				target_enemy = null
				target_position = mouse_pos
				is_moving_to_click = true
		else:
			# ---> NEU: Taste WURDE LOSGELASSEN! <---
			is_holding_mouse = false

	# (Der Rest mit "attack" bleibt gleich)
	elif event.is_action_pressed("attack") and not event is InputEventMouseButton:
		target_enemy = null
		var aim = global_position
		if last_direction == "right": aim.x += 10
		elif last_direction == "left": aim.x -= 10
		elif last_direction == "down": aim.y += 10
		elif last_direction == "up": aim.y -= 10
		_starte_angriff(aim)

	# --- HINWEIS: Hier hast du einen doppelten Input-Block für MOUSE_BUTTON_LEFT
	# den ich absichtlich unberührt gelassen habe, damit nichts von deiner Logik kaputtgeht ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		
		var clicked_enemy = null
		var alle_monster = get_tree().get_nodes_in_group("Enemies")
		for enemy in alle_monster:
			if is_instance_valid(enemy) and not enemy.is_dead and enemy.is_active:
				if mouse_pos.distance_to(enemy.global_position) < 20.0:
					clicked_enemy = enemy
					break
					
		if clicked_enemy:
			if Input.is_key_pressed(KEY_SHIFT):
				target_enemy = null
				_starte_angriff(mouse_pos)
			else:
				target_enemy = clicked_enemy
				is_moving_to_click = false 
		elif Input.is_key_pressed(KEY_SHIFT):
			target_enemy = null
			_starte_angriff(mouse_pos)
		else:
			target_enemy = null
			target_position = mouse_pos
			is_moving_to_click = true

	elif event.is_action_pressed("attack") and not event is InputEventMouseButton:
		target_enemy = null
		var aim = global_position
		if last_direction == "right": aim.x += 10
		elif last_direction == "left": aim.x -= 10
		elif last_direction == "down": aim.y += 10
		elif last_direction == "up": aim.y -= 10
		_starte_angriff(aim)

func _starte_angriff(ziel_position: Vector2):
	is_attacking = true
	is_moving_to_click = false 
	target_enemy = null 
	velocity = Vector2.ZERO
	
	var attack_dir = global_position.direction_to(ziel_position)
	if abs(attack_dir.x) > abs(attack_dir.y):
		last_direction = "right" if attack_dir.x > 0 else "left"
	else:
		last_direction = "down" if attack_dir.y > 0 else "up"
		
	anim.play("attack_" + last_direction)
	if has_node("SfxAttack"):
		$SfxAttack.play() # <--- NEU: Schwert-Sound!
	_deal_damage_to_enemies() 

func _physics_process(_delta):
	if is_dead: 
		return
		
	if is_attacking:
		move_and_slide() 
		return

	# ---> NEU: Die sichere Variante! Er fragt unser Gedächtnis, nicht die Hardware!
	if is_holding_mouse and not Input.is_key_pressed(KEY_SHIFT) and target_enemy == null:
		target_position = get_global_mouse_position()
		is_moving_to_click = true

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_direction = Vector2.ZERO 
	
	# ... (Dein restlicher Code ab hier bleibt exakt gleich!) ...

	input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	move_direction = Vector2.ZERO 
	
	if input_dir != Vector2.ZERO:
		is_moving_to_click = false
		target_enemy = null
		move_direction = input_dir
		velocity = move_direction * SPEED
		
	elif target_enemy != null:
		if is_instance_valid(target_enemy) and not target_enemy.is_dead:
			var dist = global_position.distance_to(target_enemy.global_position)
			if dist <= ATTACK_RANGE:
				var aim_pos = target_enemy.global_position
				_starte_angriff(aim_pos)
			else:
				move_direction = global_position.direction_to(target_enemy.global_position)
				velocity = move_direction * SPEED
		else:
			target_enemy = null
			velocity = Vector2.ZERO
			
	elif is_moving_to_click:
		if global_position.distance_to(target_position) > 5.0:
			move_direction = global_position.direction_to(target_position)
			velocity = move_direction * SPEED
		else:
			velocity = Vector2.ZERO
			is_moving_to_click = false
	else:
		velocity = Vector2.ZERO

	# ---> HIER WAR DER FEHLER: Dieser Block hat den Angriff unterbrochen! <---
	# NEU: Er wird nur ausgeführt, wenn wir NICHT angreifen.
	if not is_attacking:
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
	# Wir warten kurz, bis das Schwert in der Animation vorne ist
	await get_tree().create_timer(0.2).timeout
	if not is_inside_tree() or is_dead: return
	
	var tree = get_tree()
	if tree == null: return
	
	# --- NEU: WERTE AUS DEM UI HOLEN ---
	var ui = tree.root.find_child("UI", true, false)
	
	# Standard-Werte (falls das UI warum auch immer fehlt)
	var angreifer_atk = 5
	var angreifer_wucht = 15.0
	
	if ui != null:
		# Hier holen wir uns die neu erstellten Variablen aus deiner ui.gd
		angreifer_atk = ui.current_total_atk
		angreifer_wucht = ui.current_total_knockback
	
	var alle_monster = tree.get_nodes_in_group("Enemies")
	for enemy in alle_monster:
		if not is_instance_valid(enemy) or enemy.is_dead or not enemy.is_active: 
			continue
		
		if global_position.distance_to(enemy.global_position) <= 45.0:
			var dir_to_enemy = global_position.direction_to(enemy.global_position)
			var hit = false
			
			# Trifft der Spieler in die Richtung, in die er schaut?
			if last_direction == "right" and dir_to_enemy.x > 0.3: hit = true
			elif last_direction == "left" and dir_to_enemy.x < -0.3: hit = true
			elif last_direction == "down" and dir_to_enemy.y > 0.3: hit = true
			elif last_direction == "up" and dir_to_enemy.y < -0.3: hit = true
			
			if hit:
				# --- NEU: DIABLO-STYLE SCHADENSBERECHNUNG ---
				# Der Schaden schwankt leicht (+/- 20% für etwas Zufall)
				var min_dmg = max(1, int(angreifer_atk * 0.8))
				var max_dmg = max(1, int(angreifer_atk * 1.2))
				var finaler_schaden = randi_range(min_dmg, max_dmg)
				
				print("Spieler schlägt zu! ATK: ", angreifer_atk, " -> Gewürfelter Schaden: ", finaler_schaden)
				
				# Wir rufen die neue Methode im Monster auf:
				# take_damage(Schaden, Unsere Position (für den Rückstoß), Unsere Wucht)
				if enemy.has_method("take_damage"):
					enemy.take_damage(finaler_schaden, global_position, angreifer_wucht)

# ---> NEU: RÜSTUNG BLOCKT SCHADEN <---
func take_damage(amount: int):
	if is_dead: return
	
	var ui = get_tree().root.find_child("UI", true, false)
	var verteidigung = 0
	
	# Rüstungswert abfragen
	if ui != null:
		verteidigung = ui.current_total_def
		
	# Echten Schaden berechnen: Monster-Schaden minus Rüstung.
	# max(1, ...) sorgt dafür, dass mindestens 1 Schaden durchkommt.
	var echter_schaden = max(1, amount - verteidigung)
	
	hp -= echter_schaden
	print("Autsch! Monster haut mit ", amount, " -> Rüstung blockt ", verteidigung, " -> ", echter_schaden, " HP verloren! Rest: ", hp)
	
	if has_node("SfxHurt"):
		$SfxHurt.play() # <--- NEU: Autsch-Sound!
	
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# Leben im UI updaten
	if ui != null:
		ui.update_health(hp, max_hp)
	
	if hp <= 0:
		is_dead = true
		velocity = Vector2.ZERO
		if has_node("SfxDeath"):
			$SfxDeath.play() # <--- NEU: Sterbe-Sound!
		print("GAME OVER - Spieler ist tot!")
		
		if anim.sprite_frames.has_animation("die"):
			anim.play("die")
			await anim.animation_finished
			
		get_tree().reload_current_scene()

func _on_animation_finished():
	if anim.animation.begins_with("attack_"):
		is_attacking = false
