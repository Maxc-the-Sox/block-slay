extends Node2D

# Referenz zum animierten Sprite (Kind-Knoten)
@onready var anim = $AnimatedSprite2D

# ZUSTÄNDE: Wir definieren, was der Spieler gerade tun kann
enum State { IDLE, WALK, ATTACK, DIE }
var current_state = State.IDLE

# Blickrichtung merken (Standard: nach unten schauen)
var last_direction = Vector2.DOWN

# --- NEU: LEBENSPUNKTE ---
var hp = 5      # Damit startest du (5 volle Herzen)
var max_hp = 10 # Das ist das absolute Maximum (5 leere Herzen)

func _ready():
	# Beim Start die richtige Stand-Animation (idle_down) spielen
	update_animation()

# --- FUNKTION 1: BEWEGEN ---
# Wird vom MainGame aufgerufen, wenn Pfeiltasten gedrückt werden
func move_visual(target_pixel_pos):
	# Wenn wir tot sind oder gerade schlagen, bewegen wir uns nicht
	if current_state == State.DIE or current_state == State.ATTACK:
		return

	# 1. Zustand auf "Laufen" setzen
	current_state = State.WALK
	
	# 2. In welche Richtung laufen wir? (Neu - Alt)
	var diff = target_pixel_pos - position
	if diff != Vector2.ZERO:
		last_direction = diff.normalized()
	
	# 3. Passende Animation (z.B. walk_right) starten
	update_animation()
	
	# 4. Die Bewegung durchführen (Tweening)
	var tween = create_tween()
	tween.tween_property(self, "position", target_pixel_pos, 0.2)
	
	# 5. Wenn Bewegung fertig -> Zurück zu Idle
	tween.tween_callback(return_to_idle)

# --- FUNKTION 2: ANGREIFEN ---
# Wird vom MainGame aufgerufen (Taste SPACE)
func attack_visual():
	if current_state == State.DIE: 
		return
	
	current_state = State.ATTACK
	update_animation() # Startet z.B. "attack_down"
	
	# Wir warten, bis die Schlag-Animation einmal durchgelaufen ist
	await anim.animation_finished
	
	return_to_idle()

# --- NEU: SCHADEN NEHMEN ---
func take_damage(amount):
	if current_state == State.DIE: return # Tote spüren keinen Schmerz
	
	hp -= amount
	print("AUA! Spieler HP: ", hp)
	
	# Visueller Effekt: Rot blinken
	modulate = Color.RED
	var t = create_tween()
	t.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	if hp <= 0:
		die_visual()

# --- FUNKTION 3: STERBEN ---
# Wird vom MainGame aufgerufen (Taste K)
func die_visual():
	current_state = State.DIE
	update_animation() # Startet z.B. "die_down"
	print("GAME OVER")
	
	# Optional: Roter Blitz als Feedback
	# modulate = Color.RED  <-- Auskommentiert, macht nichts mehr

# --- HILFSFUNKTIONEN ---

func return_to_idle():
	# Nur aufstehen, wenn wir nicht tot sind
	if current_state != State.DIE:
		current_state = State.IDLE
		update_animation()

func update_animation():
	# HIER BAUEN WIR DEN NAMEN ZUSAMMEN: "aktion_richtung"
	
	# 1. Die Richtung bestimmen (left, right, up, down)
	var dir_name = "down"
	
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0: dir_name = "right"
		else: dir_name = "left"
	else:
		if last_direction.y > 0: dir_name = "down" # Y ist in Godot nach unten positiv
		else: dir_name = "up"
	
	# 2. Die Aktion bestimmen (idle_, walk_, attack_, die_)
	var prefix = "idle_"
	
	if current_state == State.WALK:
		prefix = "walk_"
	elif current_state == State.ATTACK:
		prefix = "attack_"
	elif current_state == State.DIE:
		prefix = "die_"
	
	# 3. Abspielen (z.B. "walk_" + "right" = "walk_right")
	anim.play(prefix + dir_name)
