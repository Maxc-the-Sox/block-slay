extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		print("Leiter gefunden! Speichere HP und lade nächste Ebene...")
		
		# ---> NEU: Wir packen die aktuellen HP in den Rucksack! <---
		GlobalData.player_hp = body.hp
		GlobalData.player_max_hp = body.max_hp
		
		get_tree().change_scene_to_file("res://main_game.tscn")
