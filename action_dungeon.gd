extends Node2D

const ROOM_SIZE = 6 # Unser 6er Raster für den perfekten Platz!
const TILE_PIXEL_SIZE = 16

# DEINE PINSEL-NUMMERN:
var pinsel_wand = 1   
var pinsel_zinne = 2

var boden_pinsel_woerterbuch = {
	0: 0, 
	1: 3, 
	2: 4, 
	3: 5  
}

# ---> DIE NEUEN ADRESSEN <---
@onready var viewport = $SubViewportContainer/SubViewport # Neu: Unser Fenster!
@onready var ysort_welt = $SubViewportContainer/SubViewport/YSortWelt # ---> NEU: Unser Sortier-Ordner!
@onready var boden_layer = $SubViewportContainer/SubViewport/YSortWelt/BodenLayer
@onready var wand_layer = $SubViewportContainer/SubViewport/YSortWelt/WandLayer
@onready var zinnen_layer = $SubViewportContainer/SubViewport/YSortWelt/ZinnenLayer
@onready var player = $SubViewportContainer/SubViewport/YSortWelt/ActionPlayer
@onready var ui = $UI # Sofern dein UI-Node im Baum genau "UI" heißt

# Lade die Gegner-Szenen schon mal vor
var gegner_szenen = [
	preload("res://GameData/monster/slime.tscn"),
	preload("res://GameData/monster/orc.tscn"),
	preload("res://GameData/monster/skeleton_archer.tscn"),
	preload("res://GameData/monster/zombie.tscn") #
]

var leiter_szene = preload("res://ladder.tscn") # NEU: Die Leiter laden
var truhe_szene = preload("res://chest.tscn") # ---> NEU: Die Schatztruhe laden!

# NEU: Das Management für die "Post-it" Schatten
var zelle_zu_raum = {} 
var unentdeckte_raeume = {}
var kachel_schatten = {} # Merkt sich jedes einzelne kleine 1x1 Schatten-Quadrat

func _ready():
	y_sort_enabled = true
	
	if GlobalData.tetris_grid.is_empty():
		print("Rucksack leer! Generiere Test-Räume...")
		GlobalData.tetris_grid[Vector2(0, 0)] = 0 
		GlobalData.tetris_grid[Vector2(0, 1)] = 1 
		GlobalData.tetris_doors[Vector2(0, 0)] = [Vector2.DOWN]
		GlobalData.tetris_doors[Vector2(0, 1)] = [Vector2.UP]
	
	generiere_dungeon()
	
	# NEU: Dem UI sagen, dass es die Herzen zeichnen soll!
	if is_instance_valid(ui):
		ui.update_health(player.hp, player.max_hp) 
		
		MusicManager.play_dungeon()

func _process(_delta):
	if is_instance_valid(player):
		var tile_x = int(floor(player.position.x / TILE_PIXEL_SIZE))
		var tile_y = int(floor(player.position.y / TILE_PIXEL_SIZE))
		
		var lokal_x = posmod(tile_x, ROOM_SIZE)
		var lokal_y = posmod(tile_y, ROOM_SIZE)
		
		if lokal_x < 5 and lokal_y < 5:
			var raum_x = floor(tile_x / float(ROOM_SIZE))
			var raum_y = floor(tile_y / float(ROOM_SIZE))
			var aktueller_raum = Vector2(raum_x, raum_y)
			
			if zelle_zu_raum.has(aktueller_raum):
				var raum_id = zelle_zu_raum[aktueller_raum]
				
				if unentdeckte_raeume.has(raum_id):
					unentdeckte_raeume.erase(raum_id) 
					
					for tetris_pos in zelle_zu_raum.keys():
						if zelle_zu_raum[tetris_pos] == raum_id:
							var start_x = int(tetris_pos.x) * ROOM_SIZE
							var start_y = int(tetris_pos.y) * ROOM_SIZE
							
							for lx in range(-1, ROOM_SIZE):
								for ly in range(-1, ROOM_SIZE):
									var welt_pos = Vector2i(start_x + lx, start_y + ly)
									if kachel_schatten.has(welt_pos):
										var s = kachel_schatten[welt_pos]
										if is_instance_valid(s):
											var tween = create_tween()
											tween.tween_property(s, "modulate:a", 0.0, 0.5)
											tween.tween_callback(s.queue_free)
										kachel_schatten.erase(welt_pos)

							for lx in range(-1, ROOM_SIZE):
								var welt_pos = Vector2i(start_x + lx, start_y - 2)
								if kachel_schatten.has(welt_pos):
									var s = kachel_schatten[welt_pos]
									if is_instance_valid(s):
										var tween = create_tween()
										tween.tween_property(s, "size:y", 8.0, 0.5)

# ---> NEU: MONSTER IN DIESEM RAUM AUFWECKEN! <---
					var alle_monster = get_tree().get_nodes_in_group("Enemies")
					for monster in alle_monster:
						if is_instance_valid(monster) and not monster.is_active:
							# Wo steht das Monster im Raster?
							var m_tile_x = int(floor(monster.position.x / TILE_PIXEL_SIZE))
							var m_tile_y = int(floor(monster.position.y / TILE_PIXEL_SIZE))
							var m_raum_x = floor(m_tile_x / float(ROOM_SIZE))
							var m_raum_y = floor(m_tile_y / float(ROOM_SIZE))
							var monster_zelle = Vector2(m_raum_x, m_raum_y)
							
							# Prüfen, ob das Monster zur exakt gleichen Raum-ID (Tetris-Teil) gehört!
							if zelle_zu_raum.has(monster_zelle) and zelle_zu_raum[monster_zelle] == raum_id:
								monster.wake_up()

	# --- NEU: RÖNTGENBLICK FÜR SPIELER UND MONSTER ---
	update_schatten(player)
	var alle_gegner = get_tree().get_nodes_in_group("Enemies") # <-- Umbenannt zu "alle_gegner"!
	for gegner in alle_gegner:
		update_schatten(gegner)

func generiere_dungeon():
	print("Starte Weltenbau: Meister-Version mit perfektem Wand-Schatten!")
	
	var alle_boden_zellen = {} 
	var start_pos_gesetzt = false

	# ==========================================
	# 0. RÄUME ZU CLUSTERN ZUSAMMENFASSEN
	# ==========================================
	var next_raum_id = 0
	for pos in GlobalData.tetris_grid.keys():
		if not zelle_zu_raum.has(pos):
			var stack = [pos]
			var farbe = GlobalData.tetris_grid[pos]
			unentdeckte_raeume[next_raum_id] = true
			
			while stack.size() > 0:
				var curr = stack.pop_back()
				if not zelle_zu_raum.has(curr):
					zelle_zu_raum[curr] = next_raum_id
					for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
						var n = curr + dir
						if GlobalData.tetris_grid.has(n) and GlobalData.tetris_grid[n] == farbe:
							stack.append(n)
			next_raum_id += 1

	# ==========================================
	# 1. RÄUME PLANEN (Boden 5x5)
	# ==========================================
	for tetris_pos in GlobalData.tetris_grid:
		var boden_id = GlobalData.tetris_grid[tetris_pos] 
		var start_x = int(tetris_pos.x) * ROOM_SIZE
		var start_y = int(tetris_pos.y) * ROOM_SIZE
		
		var hat_rechts = GlobalData.tetris_grid.has(tetris_pos + Vector2(1, 0)) and GlobalData.tetris_grid[tetris_pos + Vector2(1, 0)] == boden_id
		var hat_unten = GlobalData.tetris_grid.has(tetris_pos + Vector2(0, 1)) and GlobalData.tetris_grid[tetris_pos + Vector2(0, 1)] == boden_id
		var hat_ecke = GlobalData.tetris_grid.has(tetris_pos + Vector2(1, 1)) and GlobalData.tetris_grid[tetris_pos + Vector2(1, 1)] == boden_id
		
		for lx in range(ROOM_SIZE):
			for ly in range(ROOM_SIZE):
				var is_boden = false
				if lx < 5 and ly < 5: is_boden = true
				elif lx == 5 and ly < 5 and hat_rechts: is_boden = true
				elif ly == 5 and lx < 5 and hat_unten: is_boden = true
				elif lx == 5 and ly == 5 and hat_rechts and hat_unten and hat_ecke: is_boden = true
				
				if is_boden:
					alle_boden_zellen[Vector2i(start_x + lx, start_y + ly)] = boden_id 
		
		if not start_pos_gesetzt:
			player.position = Vector2((start_x + 2.0) * TILE_PIXEL_SIZE, (start_y + 2.0) * TILE_PIXEL_SIZE)
			start_pos_gesetzt = true

	# ==========================================
	# 1.5 TÜREN PLANEN (Der Lieferschein)
	# ==========================================
	var tueren_zellen = {}
	if "tetris_doors" in GlobalData:
		for tetris_pos in GlobalData.tetris_doors.keys():
			var start_x = int(tetris_pos.x) * ROOM_SIZE
			var start_y = int(tetris_pos.y) * ROOM_SIZE
			for dir in GlobalData.tetris_doors[tetris_pos]:
				var tuer_lokal = Vector2i.ZERO
				if dir == Vector2.RIGHT: tuer_lokal = Vector2i(5, 2)
				elif dir == Vector2.LEFT: tuer_lokal = Vector2i(-1, 2)
				elif dir == Vector2.DOWN: tuer_lokal = Vector2i(2, 5)
				elif dir == Vector2.UP: tuer_lokal = Vector2i(2, -1)
				
				var welt_tuer_pos = Vector2i(start_x, start_y) + tuer_lokal
				tueren_zellen[welt_tuer_pos] = true
				alle_boden_zellen[welt_tuer_pos] = GlobalData.tetris_grid[tetris_pos]

	# ==========================================
	# 2. DYNAMISCHE GRENZEN BERECHNEN
	# ==========================================
	var min_x = 99999; var max_x = -99999; var min_y = 99999; var max_y = -99999
	for pos in alle_boden_zellen.keys():
		if pos.x < min_x: min_x = pos.x
		if pos.x > max_x: max_x = pos.x
		if pos.y < min_y: min_y = pos.y
		if pos.y > max_y: max_y = pos.y
	min_x -= 5; max_x += 5; min_y -= 5; max_y += 5

	# ==========================================
	# 3. DIE GRENZKONTROLLE 
	# ==========================================
	var mauer_zellen = []
	var finale_boden_zellen = {} 
	var zellen_pro_boden = {0: [], 1: [], 2: [], 3: []} 
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos = Vector2i(x, y)
			if tueren_zellen.has(pos):
				finale_boden_zellen[pos] = true
				var farbe = 0
				if alle_boden_zellen.has(pos + Vector2i.LEFT): farbe = alle_boden_zellen[pos + Vector2i.LEFT]
				elif alle_boden_zellen.has(pos + Vector2i.UP): farbe = alle_boden_zellen[pos + Vector2i.UP]
				zellen_pro_boden[farbe].append(pos)
				continue
			if not alle_boden_zellen.has(pos):
				mauer_zellen.append(pos) 
			else:
				var meine_farbe = alle_boden_zellen[pos]
				finale_boden_zellen[pos] = true
				zellen_pro_boden[meine_farbe].append(pos)

	# ==========================================
	# 4. DAS ZEICHNEN
	# ==========================================
	wand_layer.clear(); zinnen_layer.clear(); boden_layer.clear()
	wand_layer.set_cells_terrain_connect(mauer_zellen, 0, pinsel_wand) 
	zinnen_layer.set_cells_terrain_connect(mauer_zellen, 0, pinsel_zinne)
	for id in zellen_pro_boden.keys():
		if zellen_pro_boden[id].size() > 0:
			boden_layer.set_cells_terrain_connect(zellen_pro_boden[id], 0, boden_pinsel_woerterbuch.get(id, 0))
	
	# ==========================================
	# ---> DIE BRECHSTANGE: Türen & Ecken reparieren! <---
	# ==========================================
	for tuer_pos in tueren_zellen.keys():
		var wl = Vector2i(tuer_pos.x - 1, tuer_pos.y); var wr = Vector2i(tuer_pos.x + 1, tuer_pos.y)
		if not finale_boden_zellen.has(wl): wand_layer.set_cell(wl, 4, Vector2i(10, 1))
		if not finale_boden_zellen.has(wr): wand_layer.set_cell(wr, 4, Vector2i(7, 1))
	for boden_pos in finale_boden_zellen.keys():
		var l = Vector2i(boden_pos.x - 1, boden_pos.y); var r = Vector2i(boden_pos.x + 1, boden_pos.y); var o = Vector2i(boden_pos.x, boden_pos.y - 1)
		if not finale_boden_zellen.has(l) and not finale_boden_zellen.has(o): wand_layer.set_cell(o, 4, Vector2i(9, 5)) 
		if not finale_boden_zellen.has(r) and not finale_boden_zellen.has(o): wand_layer.set_cell(o, 4, Vector2i(7, 5))
			
	# ==========================================
	# 5. TÜREN SPAWNEN & PIXEL-KORREKTUR
	# ==========================================
	var action_door_scene = preload("res://ActionDoor.tscn")
	for tuer_pos in tueren_zellen.keys():
		var d = action_door_scene.instantiate()
		var basis_pos = (Vector2(tuer_pos) + Vector2(0.5, 0.5)) * TILE_PIXEL_SIZE
		if posmod(tuer_pos.x, ROOM_SIZE) == 5:
			d.door_type = "side"
			d.position = basis_pos + Vector2(11, -8) 
		else:
			d.door_type = "front"
			d.position = basis_pos + Vector2(1, -9) 
		
		# ---> NEU: Tür in YSortWelt einfügen <---
		ysort_welt.add_child(d)

	# ==========================================
	# 6. FOG OF WAR (Schatten verteilen)
	# ==========================================
	for pos in finale_boden_zellen.keys(): _erstelle_schatten_kachel(pos)
	for pos in mauer_zellen: _erstelle_schatten_kachel(pos)

	# ==========================================
	# 7. MONSTER AUS DEM RUCKSACK LADEN (REPARIERT)
	# ==========================================
	for tetris_pos in GlobalData.monster_positionen:
		var start_x = int(tetris_pos.x) * ROOM_SIZE
		var start_y = int(tetris_pos.y) * ROOM_SIZE
		
		var zufalls_index = randi() % gegner_szenen.size()
		var gegner = gegner_szenen[zufalls_index].instantiate()
		
		# Wir setzen sie in die Mitte des Raums (3, 3)
		var basis_pos = Vector2(start_x + 3.0, start_y + 3.0)
		gegner.position = basis_pos * TILE_PIXEL_SIZE
		
		# ---> NEU: Monster in YSortWelt einfügen <---
		ysort_welt.add_child(gegner)

	# ==========================================
	# 8. DIE LEITER IN DEN HÖCHSTEN RAUM SETZEN
	# ==========================================
	var hoechster_raum = Vector2(0, 99) # Ein fiktiver tiefer Startwert
	
	# Wir suchen den Raum, der am weitesten oben im Tetris-Feld ist (kleinstes Y)
	for pos in GlobalData.tetris_grid.keys():
		if pos.y < hoechster_raum.y:
			hoechster_raum = pos
			
	# Leiter erstellen und genau in die Mitte (2.5, 2.5) dieses Raumes platzieren
	var leiter = leiter_szene.instantiate()
	var leiter_basis_pos = Vector2(hoechster_raum.x * ROOM_SIZE + 2.5, hoechster_raum.y * ROOM_SIZE + 2.5)
	
	leiter.position = leiter_basis_pos * TILE_PIXEL_SIZE
	
	# ---> NEU: Leiter in YSortWelt einfügen <---
	ysort_welt.add_child(leiter)

	# ==========================================
	# 9. SCHATZTRUHEN AUS DEM RUCKSACK LADEN (Jetzt an der richtigen Stelle!)
	# ==========================================
	if "truhen_positionen" in GlobalData:
		for tetris_pos in GlobalData.truhen_positionen:
			var start_x = int(tetris_pos.x) * ROOM_SIZE
			var start_y = int(tetris_pos.y) * ROOM_SIZE
			
			var truhe = truhe_szene.instantiate()
			var basis_pos = Vector2(start_x + 3.0, start_y + 3.0)
			truhe.position = basis_pos * TILE_PIXEL_SIZE
			
			ysort_welt.add_child(truhe)

# ==========================================
# Hilfsfunktion, die unten separat steht!
# ==========================================
func _erstelle_schatten_kachel(pos: Vector2i):
	if not kachel_schatten.has(pos):
		var schatten = ColorRect.new()
		schatten.color = Color(0, 0, 0, 0.8)
		schatten.size = Vector2(TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
		schatten.position = Vector2(pos) * TILE_PIXEL_SIZE
		schatten.z_index = 50
		viewport.add_child(schatten)
		kachel_schatten[pos] = schatten

# ==========================================
# ---> NEU: RÖNTGENBLICK FUNKTION <---
# ==========================================
func update_schatten(figur):
	if not is_instance_valid(figur): return
	
	# Hat die Figur überhaupt einen Klon?
	var schatten = figur.get_node_or_null("Schatten")
	var original_sprite = figur.get_node_or_null("AnimatedSprite2D")
	
	if schatten and original_sprite:
		# Wo steht die Figur im Raster?
		var tile_x = int(floor(figur.position.x / TILE_PIXEL_SIZE))
		var tile_y = int(floor(figur.position.y / TILE_PIXEL_SIZE))
		
		# Die Kachel direkt "vor/unter" der Figur (also y + 1)
		var check_pos = Vector2i(tile_x, tile_y + 1)
		
		# ---> KORREKTUR: Godot 4.3 TileMapLayer braucht nur die Koordinate! <---
		var is_wall = wand_layer.get_cell_source_id(check_pos) != -1
		
		# Klon anzeigen oder verstecken!
		schatten.visible = is_wall
		
		# Bewegung des Klons exakt mit dem Original synchronisieren, damit er mitläuft!
		schatten.animation = original_sprite.animation
		schatten.frame = original_sprite.frame
		schatten.flip_h = original_sprite.flip_h
