extends Node2D

@onready var anim = $AnimatedSprite2D
@onready var interact_area = $InteractArea

# Hier landen die Items
@export var truhen_inhalt: Array[ItemData] = []

var is_opened = false
var player_in_range = false

func _ready():
	anim.play("idle")
	anim.offset = Vector2(0, -8)
	
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	
	# Truhe beim Start befüllen
	if LootManager:
		var item1 = LootManager.generiere_zufalls_item()
		var item2 = LootManager.generiere_zufalls_item()
		
		if item1: truhen_inhalt.append(item1)
		if item2: truhen_inhalt.append(item2)

# ==========================================
# 1. PRÜFEN, OB DER SPIELER DA IST
# ==========================================
func _on_body_entered(body):
	if body.name == "ActionPlayer":
		player_in_range = true

func _on_body_exited(body):
	if body.name == "ActionPlayer":
		player_in_range = false
		
		# Fenster schließen, wenn der Spieler weggeht
		var ui = get_tree().root.find_child("UI", true, false)
		if ui:
			ui.close_loot_window()

# ==========================================
# 2. STEUERUNG (E & DOPPELKLICK)
# ==========================================
func _input(event):
	# WICHTIG: Das "not is_opened" wurde hier entfernt! 
	# Man darf immer interagieren, solange man in Reichweite ist.
	if player_in_range:
		
		# A) Taste E
		if event is InputEventKey and event.pressed and event.keycode == KEY_E:
			open_chest()
			
		# B) Linke Maustaste Doppelklick
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			open_chest()

# ==========================================
# 3. DIE TRUHE ÖFFNEN / LOOT ZEIGEN
# ==========================================
func open_chest():
	var ui = get_tree().root.find_child("UI", true, false)
	if ui:
		# Wir geben jetzt zusätzlich 'self' mit, damit die UI weiß, 
		# zu welcher Truhe der Loot gehört!
		ui.fill_loot_window(truhen_inhalt, self) 
		print("Gegenstände in der Truhe sichtbar gemacht.")
	
	if not is_opened:
		is_opened = true
		anim.play("open")

	# Jetzt prüfen wir: Wurde die Animation schon mal abgespielt?
	if is_opened: 
		return # Wenn ja, brechen wir hier ab (Animation bleibt beim letzten Frame)
	
	# Wenn nein (das allererste Mal):
	is_opened = true
	anim.play("open")
	print("Truhe wird zum ersten Mal animiert!")
