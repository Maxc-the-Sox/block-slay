extends Node2D

@onready var anim = $AnimatedSprite2D
var is_opened = false

func _ready():
	anim.play("idle")
	# WICHTIG: Offset anpassen, damit die Truhe mittig im Feld steht
	anim.offset = Vector2(0, -8) # Je nach Bildgröße anpassen!

func open_chest():
	if is_opened: return
	is_opened = true
	anim.play("open")
	
	# Wir warten, bis die Animation fertig ist, dann löschen wir die Truhe
	await anim.animation_finished
	queue_free()
