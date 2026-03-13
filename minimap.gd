extends Control

const CELL_SIZE = 8 # Wie groß soll ein Raum auf der Karte sein? (8x8 Pixel)

# Die gleichen Farben wie in deinem Tetris-Modus
const COLORS = [
	Color("#5e6875"), # 0: Stein
	Color("#634b35"), # 1: Erde
	Color("#3b4f29"), # 2: Sumpf
	Color("#6e2c2c")  # 3: Ziegel
]

var player_raum_pos = Vector2.ZERO

func _process(_delta):
	# Sucht den Spieler in der Welt, um seinen Punkt zu zeichnen
	var player = get_tree().get_first_node_in_group("Player")
	if is_instance_valid(player):
		# Berechnet, in welchem Tetris-Raum der Spieler gerade steht 
		# (16 Pixel pro Kachel * 6 Kacheln pro Raum = 96 Pixel)
		var raum_x = floor(player.position.x / 96.0)
		var raum_y = floor(player.position.y / 96.0)
		player_raum_pos = Vector2(raum_x, raum_y)
	
	# Sagt Godot: "Bitte male die Karte jeden Frame neu!"
	queue_redraw()

func _draw():
	if GlobalData.tetris_grid.is_empty(): return
	
	# 1. Den "Nullpunkt" der Karte finden (damit sie oben links anfängt)
	var min_pos = Vector2(9999, 9999)
	for pos in GlobalData.tetris_grid.keys():
		if pos.x < min_pos.x: min_pos.x = pos.x
		if pos.y < min_pos.y: min_pos.y = pos.y
		
	# 2. Alle Räume als farbige Quadrate zeichnen
	for pos in GlobalData.tetris_grid.keys():
		var farb_id = GlobalData.tetris_grid[pos]
		
		# Position auf der Minimap berechnen
		var draw_pos = (pos - min_pos) * CELL_SIZE
		
		# Das Quadrat für den Raum malen
		draw_rect(Rect2(draw_pos, Vector2(CELL_SIZE, CELL_SIZE)), COLORS[farb_id])
		
		# Einen kleinen schwarzen Rahmen drum herum zeichnen, damit man die Blöcke sieht
		draw_rect(Rect2(draw_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.BLACK, false, 1.0)
		
	# 3. Den Spieler als weißen Punkt einzeichnen
	var p_draw_pos = (player_raum_pos - min_pos) * CELL_SIZE
	var center_punkt = p_draw_pos + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	draw_circle(center_punkt, CELL_SIZE / 3.0, Color.WHITE)
