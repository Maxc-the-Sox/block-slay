extends CharacterBody2D

@export var max_hp: int = 3
@export var speed: float = 60.0
@export var attack_damage: int = 1
@export var attack_range: float = 25.0 # Wie nah muss er ran, um zuzuhauen?
@export var defense: int = 0

# Erzeugt ein Dropdown-Menü im Editor!
@export_enum("Leicht", "Mittel", "Massiv") var gewicht: String = "Leicht"

var current_hp: int
var player: Node2D = null
var last_direction: String = "down"

# Zustände des Monsters
var is_attacking: bool = false
var is_dead: bool = false
var is_active: bool = false # NEU: Das Monster schläft am Anfang!

# --- WUCHT-BASIERTER KNOCKBACK (physikalisch, respektiert Wand-Kollision) ---
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
const KNOCKBACK_DURATION: float = 0.2

@onready var anim = $AnimatedSprite2D

# ---> NEU: Unsere Variable für den Lebensbalken
var health_bar: TextureProgressBar

func _ready():
	current_hp = max_hp
	visible = false # Versteckt im Nebel
	
	if anim:
		anim.animation_finished.connect(_on_animation_finished)
	
	player = get_tree().get_first_node_in_group("Player")
	add_to_group("Enemies") # Gibt dem Monster automatisch sein Namensschild!

	# ==========================================
	# NEU: LEBENSBALKEN WIRD AUTOMATISCH GEBAUT
	# ==========================================
	health_bar = TextureProgressBar.new()
	health_bar.name = "HealthBar"
	add_child(health_bar) # Hängt den Balken an das Monster an
	
	# Wir erschaffen zwei kleine "Fake"-Bilder (30x4 Pixel groß)
	var bg_tex = PlaceholderTexture2D.new()
	bg_tex.size = Vector2(30, 4)
	var fg_tex = PlaceholderTexture2D.new()
	fg_tex.size = Vector2(30, 4)
	
	# Hintergrund: Dunkelgrau
	health_bar.texture_under = bg_tex
	health_bar.tint_under = Color(0.1, 0.1, 0.1, 0.8)
	
	# Vordergrund: Klassisches Rot
	health_bar.texture_progress = fg_tex
	health_bar.tint_progress = Color(0.8, 0.1, 0.1, 1.0)
	
	# Position: Mittig über dem Kopf (x = -15, y = -40)
	# (Du kannst die -40 bei 'y' ändern, falls der Balken im Gesicht oder zu hoch hängt)
	health_bar.position = Vector2(-15, -20)
	
	# Werte setzen und Balken verstecken
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	health_bar.hide()

# NEU: Wird vom Dungeon gerufen, wenn das Licht angeht!
func wake_up():
	if is_dead: return
	is_active = true
	visible = true

func _physics_process(delta):
	if is_dead:
		return

	if knockback_timer > 0.0:
		knockback_timer = max(knockback_timer - delta, 0.0)
		velocity = knockback_velocity * (knockback_timer / KNOCKBACK_DURATION)
		move_and_slide()
		return

	# Wenn schläft, greift an, oder kein Spieler da -> stehen bleiben
	if is_attacking or player == null or not is_active:
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

func take_damage(amount: int, attacker_pos: Vector2 = Vector2.ZERO, wucht: float = 15.0):
	if is_dead: return
	
	# 1. VERTEIDIGUNG BERECHNEN
	var echter_schaden = max(1, amount - defense)
	current_hp -= echter_schaden
	
	print(name, " kriegt ", echter_schaden, " Schaden! (", amount, " abzüglich ", defense, " Rüstung)")
	
	# ---> NEU: LEBENSBALKEN AKTUALISIEREN <---
	if health_bar:
		health_bar.show() # Zeig dich!
		health_bar.value = current_hp
	
	# 2. SOUND
	if has_node("SfxHurt"):
		$SfxHurt.play()
		
	# 3. RÜCKSTOSS BERECHNEN (KNOCKBACK)
	if attacker_pos != Vector2.ZERO:
		var flug_richtung = attacker_pos.direction_to(global_position)
		var flug_distanz = 0.0
		
		if gewicht == "Leicht":
			flug_distanz = wucht * 2.0 
		elif gewicht == "Mittel":
			flug_distanz = wucht * 1.0 
		elif gewicht == "Massiv":
			flug_distanz = 0.0 
			
		if flug_distanz > 0:
			# Lineares Abklingen: Durchschnittsgeschwindigkeit ist die Hälfte der Anfangsgeschwindigkeit
			knockback_velocity = flug_richtung * (flug_distanz * 2.0 / KNOCKBACK_DURATION)
			knockback_timer = KNOCKBACK_DURATION
	
	# 4. BLINKEN (Treffer-Feedback)
	modulate = Color.RED
	var color_tween = create_tween()
	color_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# 5. TOD CHECKEN
	if current_hp <= 0:
		die()

func die():
	is_dead = true
	is_active = false
	velocity = Vector2.ZERO
	
	# ---> NEU: LEBENSBALKEN BEIM TOD VERSTECKEN <---
	if health_bar:
		health_bar.hide()
	
	# ---> NEU: SOUND FÜR DAS STERBEN <---
	if has_node("SfxDeath"):
		$SfxDeath.play()
	
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	# --- NEU: RICHTUNG BASIEREND AUF SPIELER-POSITION ---
	var animation_zu_spielen = "die_front"
	
	if is_instance_valid(player):
		var richtung_vom_spieler = player.global_position.direction_to(global_position)
		
		if abs(richtung_vom_spieler.x) > abs(richtung_vom_spieler.y):
			animation_zu_spielen = "die_front"
			anim.flip_h = richtung_vom_spieler.x < 0
		else:
			if richtung_vom_spieler.y < 0:
				animation_zu_spielen = "die_back"
			else:
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
	if anim.animation.begins_with("attack"):
		is_attacking = false 
	elif anim.animation.begins_with("die"):
		await get_tree().create_timer(3.0).timeout
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		await tween.finished
		queue_free()

func _on_idle_timer_timeout():
	if not is_dead and is_active:
		if has_node("SfxIdle"):
			$SfxIdle.play()
		$IdleTimer.wait_time = randf_range(3.0, 8.0)
