extends Area2D

func _ready():
	# Die Leiter lauscht darauf, ob jemand drauftritt
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Prüfen, ob es wirklich der Spieler ist (und nicht etwa ein wandernder Ork)
	if body.is_in_group("Player"):
		print("Leiter gefunden! Lade nächste Ebene...")
		
		# Hier wechseln wir die Szene zurück zum Tetris-Spiel!
		# WICHTIG: Prüfe, ob deine Tetris-Szene wirklich "main_game.tscn" heißt. 
		# Falls sie anders heißt, musst du den Namen hier anpassen!
		get_tree().change_scene_to_file("res://main_game.tscn")
