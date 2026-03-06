extends Node2D

@onready var anim = $AnimatedSprite2D

# Die physischen Wände
@onready var wall_front = $StaticBody2D/WallFront
@onready var wall_side = $StaticBody2D/WallSide

# Die Sensoren
@onready var sensor_front = $Area2D/SensorFront
@onready var sensor_side = $Area2D/SensorSide

var is_open = false
var door_type = "front" # Wird vom Dungeon-Generator gesetzt

func _ready():
	# Erstmal alles aus
	wall_front.disabled = true
	wall_side.disabled = true
	sensor_front.disabled = true
	sensor_side.disabled = true
	
	# Nur die richtigen Shapes für den Typ aktivieren
	if door_type == "side":
		anim.play("closed_side") # Du musst diese Animationen im Sprite erstellen!
		wall_side.disabled = false
		sensor_side.disabled = false
	else:
		anim.play("closed_front")
		wall_front.disabled = false
		sensor_front.disabled = false

# Signal von Area2D (body_entered)
func _on_area_2d_body_entered(body):
	if body.name == "ActionPlayer" and not is_open:
		open_door()

func open_door():
	is_open = true
	
	# ---> NEU: TÜR KNARRT! <---
	# Wir spielen den Sound direkt ab, wenn die Tür den Befehl zum Öffnen bekommt.
	if has_node("SfxOpen"):
		$SfxOpen.play()
	
	if door_type == "side":
		anim.play("opening_side")
		wall_side.set_deferred("disabled", true) # Mauer weg!
	else:
		anim.play("opening_front")
		wall_front.set_deferred("disabled", true) # Mauer weg!
