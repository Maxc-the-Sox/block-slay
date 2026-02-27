extends Node2D

@onready var anim = $AnimatedSprite2D

@export var hp = 3
var logical_pos = Vector2.ZERO 

# Wir merken uns die letzte Richtung für die Todes- UND Idle-Animation
var last_move_dir = Vector2.DOWN 

# Einstellungen
var aggro_range = 5.0
var is_pushed = false

func _ready():
	play_correct_idle()

# --- HELPER: SICHERE ANIMATIONEN (Der Absturz-Fix!) ---
# Diese Funktion prüft: "Hast du 'walk_up'? Nein? Dann spiel 'walk'."
func play_directional_anim(base_name, dir):
	var suffix = ""
	if dir == Vector2.UP: suffix = "_up"
	elif dir == Vector2.DOWN: suffix = "_down"
	elif dir == Vector2.LEFT: suffix = "_left"
	elif dir == Vector2.RIGHT: suffix = "_right"
	
	var specific_anim = base_name + suffix
	
	# Check: Hat das Monster die Richtung? (z.B. "attack_up")
	if anim.sprite_frames.has_animation(specific_anim):
		anim.play(specific_anim)
	# Fallback: Hat das Monster die Basis? (z.B. "attack")
	elif anim.sprite_frames.has_animation(base_name):
		anim.play(base_name)

# --- HELPER: IDLE ANIMATION ---
func play_correct_idle():
	# WICHTIG: Wenn tot, nicht mehr aufstehen!
	if hp <= 0: return

	if anim.sprite_frames.has_animation("idle_front"):
		if last_move_dir == Vector2.DOWN or last_move_dir == Vector2.LEFT:
			anim.play("idle_front")
		else:
			anim.play("idle_back")
	elif anim.sprite_frames.has_animation("idle"):
		anim.play("idle")

# --- KI LOGIK ---
func do_turn(target_grid_pos, player_node):
	if hp <= 0: return

	if is_pushed:
		is_pushed = false
		play_correct_idle() 
		return 

	var dist = logical_pos.distance_to(target_grid_pos)
	
	if dist <= aggro_range:
		try_chase_player(target_grid_pos, player_node)
	else:
		do_random_move()

func try_chase_player(target_pos, player_node):
	var diff = target_pos - logical_pos
	var x_dir = Vector2(sign(diff.x), 0)
	var y_dir = Vector2(0, sign(diff.y))
	
	var primary_dir = Vector2.ZERO
	var secondary_dir = Vector2.ZERO
	
	if abs(diff.x) > abs(diff.y):
		primary_dir = x_dir; secondary_dir = y_dir
	else:
		primary_dir = y_dir; secondary_dir = x_dir
		
	# Versuch 1: Hauptrichtung
	if primary_dir != Vector2.ZERO:
		var check_pos = logical_pos + primary_dir
		
		if check_pos == target_pos:
			if not is_blocked_by_wall(check_pos):
				perform_attack(player_node, primary_dir); return 
		
		if can_move_to(check_pos):
			move_to(check_pos); return

	# Versuch 2: Nebenrichtung
	if secondary_dir != Vector2.ZERO:
		var check_pos = logical_pos + secondary_dir
		
		if check_pos == target_pos:
			if not is_blocked_by_wall(check_pos):
				perform_attack(player_node, secondary_dir); return 
		
		if can_move_to(check_pos):
			move_to(check_pos); return

func do_random_move():
	if randf() > 0.3: return
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var random_dir = dirs.pick_random()
	var target = logical_pos + random_dir
	var main_game = get_parent()
	
	if can_move_to(target) and target != main_game.logical_player_pos:
		move_to(target)

# --- ZENTRALER WAND-CHECK ---
func is_blocked_by_wall(target_pos):
	var main_game = get_parent()
	
	if not main_game.grid_data.has(target_pos): return true 
	
	var my_color = main_game.grid_data[logical_pos]
	var target_color = main_game.grid_data[target_pos]
	var dir = target_pos - logical_pos
	
	if my_color != target_color:
		if not main_game.is_door_open(logical_pos, dir):
			return true 
			
	return false 

func can_move_to(target_pos):
	var main_game = get_parent()
	
	if is_blocked_by_wall(target_pos): return false
	if main_game.get_enemy_at(target_pos): return false
	
	return true 

# --- BEWEGUNG ---
func move_to(target_grid_pos):
	var main_game = get_parent()
	var pixel_target = main_game.get_pixel_pos(target_grid_pos)
	var dir_vector = target_grid_pos - logical_pos
	
	last_move_dir = dir_vector
	logical_pos = target_grid_pos 
	
	# HIER WAR DAS ABSTURZ-RISIKO:
	# Statt anim.play("walk_up") nutzen wir jetzt die sichere Funktion:
	play_directional_anim("walk", dir_vector)
	
	var tween = create_tween()
	tween.tween_property(self, "position", pixel_target, 0.3)
	tween.tween_callback(play_correct_idle)

# --- ANGRIFF ---
func perform_attack(player_node, dir):
	last_move_dir = dir
	
	# HIER WAR AUCH EIN RISIKO:
	# Statt anim.play("attack_up") nutzen wir die sichere Funktion:
	play_directional_anim("attack", dir)
	
	player_node.take_damage(1)
	await anim.animation_finished
	play_correct_idle()

# --- SONSTIGES ---
func push_back(target_grid_pos, target_pixel_pos):
	is_pushed = true
	logical_pos = target_grid_pos
	var tween = create_tween()
	tween.tween_property(self, "position", target_pixel_pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	modulate = Color.RED
	tween.tween_callback(func(): modulate = Color.WHITE)
	tween.tween_callback(play_correct_idle)

func take_damage(amount):
	hp -= amount
	modulate = Color.RED
	var t = create_tween()
	t.tween_property(self, "modulate", Color.WHITE, 0.2)
	# Wichtig: Wenn er stirbt, muss die Animation hier starten
	if hp <= 0: die()

func die():
	if anim.sprite_frames.has_animation("die_front"):
		if last_move_dir == Vector2.DOWN or last_move_dir == Vector2.LEFT:
			anim.play("die_front")
		else:
			anim.play("die_back")
	else:
		anim.play("die")

	await get_tree().create_timer(1.0).timeout
	queue_free()
