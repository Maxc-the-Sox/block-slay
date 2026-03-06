extends AudioStreamPlayer

# --- DEINE PLAYLISTS ---
# Trage hier die exakten Pfade zu deinen Musikdateien ein!
var tetris_tracks = [
	preload("res://music/Block Lava Dungeon LOOP.wav"),
	preload("res://music/Block Sad Theme LOOP.wav")
]

var dungeon_tracks = [
	preload("res://music/AD Dark Castle.wav"),
	preload("res://music/AD Dungeon Ambience.wav"),
	preload("res://music/AD Dungeon Tension.wav"),
	preload("res://music/AD Fallen Remnants.wav")
]

var current_mode = "" # Merkt sich, in welchem Spielmodus wir gerade sind

func _ready():
	# Wenn ein Lied zu Ende ist, sagt dieser Befehl dem DJ: "Spiel sofort ein neues!"
	finished.connect(_on_track_finished)

func play_tetris():
	if current_mode == "tetris" and playing:
		return # Läuft schon? Dann nicht von vorne anfangen!
		
	current_mode = "tetris"
	stream = tetris_tracks.pick_random() # Wählt ein zufälliges Lied aus der Tetris-Liste
	play()

func play_dungeon():
	if current_mode == "dungeon" and playing:
		return # Läuft schon? Dann nicht von vorne anfangen!
		
	current_mode = "dungeon"
	stream = dungeon_tracks.pick_random() # Wählt ein zufälliges Lied aus der Dungeon-Liste
	play()

func _on_track_finished():
	# Wenn das Lied vorbei ist, spielen wir einfach noch ein zufälliges aus derselben Kategorie!
	if current_mode == "tetris":
		stream = tetris_tracks.pick_random()
		play()
	elif current_mode == "dungeon":
		stream = dungeon_tracks.pick_random()
		play()
