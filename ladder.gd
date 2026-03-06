extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		print("Leiter gefunden! Speichere HP und lade nächste Ebene...")
		
		GlobalData.player_hp = body.hp
		GlobalData.player_max_hp = body.max_hp
		
		# 1. Den Sound starten
		$SfxLadder.play()
		
		# 2. Den Spieler unsichtbar/unbeweglich machen (damit er nicht weiterläuft)
		body.visible = false
		body.set_physics_process(false)
		
		# 3. Das Spiel anhalten und warten, bis der Leiter-Sound GANZ zu Ende gespielt ist!
		await $SfxLadder.finished
		
		# 4. ERST DANN die Szene wechseln!
		get_tree().change_scene_to_file("res://main_game.tscn")
