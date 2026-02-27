extends Node2D

# --- KONFIGURATION ---
const TILE_SIZE = 32
const GRID_WIDTH = 10
const GRID_HEIGHT = 20
const BOARD_OFFSET = Vector2(240, 5)
const MAX_PLAYER_HP = 10 

# --- FORMEN & FARBEN ---
const SHAPES = [
	[Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,1)], 
	[Vector2(0,0), Vector2(-1,0), Vector2(1,0), Vector2(2,0)], 
	[Vector2(0,0), Vector2(-1,0), Vector2(0,1), Vector2(1,1)], 
	[Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(-1,1)], 
	[Vector2(0,0), Vector2(-1,0), Vector2(1,0), Vector2(-1,1)], 
	[Vector2(0,0), Vector2(-1,0), Vector2(1,0), Vector2(1,1)], 
	[Vector2(0,0), Vector2(-1,0), Vector2(1,0), Vector2(0,1)]
]

const COLORS = [
	Color("#5e6875"), # 0: Stein
	Color("#634b35"), # 1: Erde
	Color("#3b4f29"), # 2: Sumpf
	Color("#6e2c2c")  # 3: Ziegel
]
const WALL_COLOR = Color(0.1, 0.1, 0.1)

# --- DATEN ---
var grid_data = {} 
var doors = {} 

var grid_age = {} 
var current_age = 0

var wall_tile_scene = preload("res://WallTile.tscn")
var wall_nodes = {} 

# TÜREN
var door_scene = preload("res://Door.tscn")
var door_nodes = {}
var opened_doors = [] 

# UI Referenz
var ui_scene = preload("res://UI.tscn")
var ui_instance = null

# Liste der aufgedeckten Bodenplatten
var revealed_cells = []

var wand_tabelle = {
	# BLOCK A (Keine Innenecken)
	0: 0, 15: 14, 1: 19, 2: 11, 4: 5, 8: 13, 5: 26, 10: 10,
	3: 24, 6: 45, 12: 42, 9: 21, 7: 27, 14: 17, 13: 25, 11: 3,
	
	# BLOCK B (1 bis 4 Löcher)
	16: 20, 32: 18, 64: 4, 128: 6,
	48: 1, 96: 9, 192: 15, 144: 7,
	80: 2, 160: 16,
	112: 36, 224: 29, 208: 30, 176: 37,
	240: 40,
	
	# BLOCK C (Ränder + gegenüberliegende Löcher)
	65: 22, 129: 23, 193: 33,
	18: 38, 130: 31, 146: 41,
	20: 44, 36: 43, 52: 47,
	40: 35, 72: 28, 104: 39,
	
	# BLOCK D (Dicke Ecken mit einem Diagonal-Loch)
	131: 34, 22: 48, 44: 46, 73: 32
}

var current_piece = []
var current_pos = Vector2(4, 0)
var current_color_idx = 0

# --- MECHANIK VARIABLEN ---
var current_has_enemy = false 
var current_has_chest = false 

var fall_timer = 0.0
var fall_speed = 1.0 

@onready var player = $Player
var player_gold = 0 

# GEGNER & OBJEKTE
var slime_scene = preload("res://slime.tscn")
var orc_scene = preload("res://orc.tscn")
var chest_scene = preload("res://Chest.tscn") 

var enemies = []
var chests = {} 

var logical_player_pos = Vector2(4, 19)

# KAMPF
var attack_mode = false
var input_locked = false

# BEWEGUNG
var move_delay_timer = 0.0
var move_delay_speed = 0.2 

# --- GAME OVER STATUS ---
var is_game_over = false 

@onready var game_over_screen = $CanvasLayer/GameOverScreen
@onready var restart_button = $CanvasLayer/GameOverScreen/RestartButton

# ICONS
@onready var monster_icon = preload("res://assets/monster_icon.png") 
@onready var chest_icon = preload("res://assets/truhe_icon.png") 
@onready var board_panel_tex = preload("res://assets/Rpg Icon Pack/User Interface/Panels/panel 330x650.png")

func _ready():
	ui_instance = ui_scene.instantiate()
	add_child(ui_instance)
	
	create_start_platform()
	update_player_visuals()
	
	var btn = game_over_screen.find_child("RestartButton", true, false)
	if btn:
		btn.pressed.connect(_on_restart_pressed)
	else:
		if restart_button: restart_button.pressed.connect(_on_restart_pressed)
	
	spawn_new_piece()
	ui_instance.update_health(player.hp, MAX_PLAYER_HP)
	ui_instance.update_gold(player_gold)

func _process(delta):
	if is_game_over: return 
	
	fall_timer += delta
	if fall_timer >= fall_speed:
		fall_timer = 0
		move_piece(Vector2.DOWN)
	
	if not input_locked:
		if Input.is_action_just_pressed("ui_accept"):
			toggle_attack_mode()
		
		if move_delay_timer > 0:
			move_delay_timer -= delta
		else:
			var move_dir = Vector2.ZERO
			if Input.is_action_pressed("ui_right"): move_dir = Vector2.RIGHT
			elif Input.is_action_pressed("ui_left"): move_dir = Vector2.LEFT
			elif Input.is_action_pressed("ui_down"): move_dir = Vector2.DOWN
			elif Input.is_action_pressed("ui_up"): move_dir = Vector2.UP
			
			if move_dir != Vector2.ZERO:
				if attack_mode:
					perform_attack(move_dir)
				else:
					try_move_player(move_dir)
				move_delay_timer = move_delay_speed
	
	queue_redraw()

func _draw():
	var panel_pos = BOARD_OFFSET + Vector2(-5, -5)
	var panel_size = Vector2(330, 650)
	draw_texture_rect(board_panel_tex, Rect2(panel_pos, panel_size), false)
	
	draw_rect(Rect2(BOARD_OFFSET, Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)), Color.BLACK, true)
	
	for p in current_piece:
		var block_pos = current_pos + p
		if block_pos.y >= 0:
			var pixel_pos = BOARD_OFFSET + (block_pos * TILE_SIZE)
			var farbe = COLORS[current_color_idx]
			
			draw_rect(Rect2(pixel_pos, Vector2(TILE_SIZE, TILE_SIZE)), farbe, true)
			draw_rect(Rect2(pixel_pos, Vector2(TILE_SIZE, TILE_SIZE)), Color.WHITE, false, 1.0)
			
			if p == current_piece[0]:
				var icon_size = Vector2(24, 24)
				var icon_pos = pixel_pos + Vector2(4, 4)
				
				if current_has_enemy:
					draw_texture_rect(monster_icon, Rect2(icon_pos, icon_size), false)
				elif current_has_chest: 
					draw_texture_rect(chest_icon, Rect2(icon_pos, icon_size), false)

func _input(event):
	if is_game_over: return 
	if input_locked: return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_A: move_piece(Vector2.LEFT)
		elif event.keycode == KEY_D: move_piece(Vector2.RIGHT)
		elif event.keycode == KEY_S: move_piece(Vector2.DOWN)
		elif event.keycode == KEY_W: rotate_piece()

# --- TETRIS LOGIK ---

func spawn_new_piece():
	current_pos = Vector2(4, 0)
	current_piece = SHAPES.pick_random().duplicate()
	current_color_idx = randi() % COLORS.size()
	
	# Zufall: Monster ODER Truhe
	current_has_enemy = false
	current_has_chest = false
	
	var r = randf()
	if r < 0.2:
		current_has_enemy = true
	elif r < 0.3:
		current_has_chest = true

	# --- DIE STOPF-LOGIK (DER VORSCHLAGHAMMER) ---
	if not is_valid_position(current_piece, current_pos):
		# 1. Den Stein SOFORT ins Raster einbrennen
		for p in current_piece:
			var final_pos = (current_pos + p).snapped(Vector2(1, 1))
			# Nur was im Grid ist (Y >= 0), wird gespeichert
			if final_pos.y >= 0 and final_pos.y < GRID_HEIGHT and final_pos.x >= 0 and final_pos.x < GRID_WIDTH:
				if not grid_data.has(final_pos):
					grid_data[final_pos] = current_color_idx
					grid_age[final_pos] = current_age
		
		# 2. Den "current_piece" leeren, damit er nicht doppelt (schwebend) gezeichnet wird
		current_piece = [] 
		
		# 3. Grafik komplett neu aufbauen
		recalculate_dungeon_layout()
		update_dungeon_graphics()
		
		# 4. Den Bildschirm zwingen, sich JETZT zu aktualisieren
		queue_redraw() 
		
		# 5. Einen winzigen Moment warten, damit das Auge den Stein sieht
		# Wir nutzen hier einen Timer, weil process_frame manchmal zu schnell ist
		await get_tree().create_timer(0.2).timeout 
		
		# 6. Ab in den Dungeon
		starte_action_dungeon()
		return
	
	# Wenn er doch passt (Normalfall), geht das Spiel einfach weiter.

	# ==========================================
	# ---> DER FEHLENDE SCHUTZ-CHECK! <---
	# Wenn der neue Stein in einem alten feststeckt: 
	# Sofort abbrechen und Dungeon laden!
	# ==========================================
	if not is_valid_position(current_piece, current_pos):
		starte_action_dungeon()
		return

func move_piece(dir):
	if is_valid_position(current_piece, current_pos + dir):
		current_pos += dir
	elif dir == Vector2.DOWN:
		lock_piece()

func rotate_piece():
	var new_shape = []
	for p in current_piece: new_shape.append(Vector2(p.y, -p.x))
	if is_valid_position(new_shape, current_pos): current_piece = new_shape

func is_valid_position(shape, pos):
	for p in shape:
		var check = pos + p
		if check.x < 0 or check.x >= GRID_WIDTH or check.y >= GRID_HEIGHT: return false
		if grid_data.has(check): return false
	return true

func lock_piece():
	current_age += 1 
	var spawn_pos_special = Vector2.ZERO 
	
	for i in range(current_piece.size()):
		var p = current_piece[i]
		var final_pos = (current_pos + p).snapped(Vector2(1, 1))
		
		grid_data[final_pos] = current_color_idx
		grid_age[final_pos] = current_age 
		
		if i == 0: spawn_pos_special = final_pos
	
	# Was spawnen wir?
	if current_has_enemy:
		if randf() < 0.5: spawn_enemy(spawn_pos_special, 1) 
		else: spawn_enemy(spawn_pos_special, 2) 
	elif current_has_chest:
		spawn_chest(spawn_pos_special)
	
	check_lines()
	recalculate_dungeon_layout()
	update_dungeon_graphics()
	
	# Der nächste Stein versucht zu spawnen. 
	# Wenn oben schon alles voll ist, greift unser Schutz in spawn_new_piece()!
	spawn_new_piece()

# --- NEU: RUCKSACK PACKEN UND SZENE WECHSELN ---
func starte_action_dungeon():
	print("Decke erreicht! Phase 1: Rucksack packen...")
	
	# 1. Die Karte speichern
	GlobalData.tetris_grid = grid_data.duplicate()
	
	# ---> NEU: 1.5 Die Türen speichern <---
	GlobalData.tetris_doors = doors.duplicate(true)
	
	# 2. Die Truhen-Positionen speichern
	GlobalData.truhen_positionen = chests.keys()
	
	# 3. Die Monster-Positionen speichern
	GlobalData.monster_positionen.clear()
	for e in enemies:
		if is_instance_valid(e):
			GlobalData.monster_positionen.append(e.logical_pos)
	
	print("Daten sind im Rucksack! Bereit für den Dungeon-Modus!")
	is_game_over = true 
	
	# Teleport in die Action-Welt!
	get_tree().change_scene_to_file("res://ActionDungeon.tscn")

# --- SPAWNER ---
func spawn_enemy(pos, type):
	var new_enemy
	if type == 1: new_enemy = slime_scene.instantiate() 
	elif type == 2: new_enemy = orc_scene.instantiate()   
	else: return 
		
	add_child(new_enemy)
	new_enemy.logical_pos = pos
	new_enemy.position = get_pixel_pos(pos)
	
	new_enemy.z_index = int(pos.y)
	
	new_enemy.visible = false 
	enemies.append(new_enemy)

func spawn_chest(pos):
	var new_chest = chest_scene.instantiate()
	add_child(new_chest)
	new_chest.position = get_pixel_pos(pos)
	new_chest.visible = false
	new_chest.z_index = int(pos.y) 
	
	chests[pos] = new_chest

# --- STANDARDS ---

func check_lines():
	var lines_to_clear = []
	for y in range(GRID_HEIGHT):
		var is_full = true
		for x in range(GRID_WIDTH):
			if not grid_data.has(Vector2(x, y)):
				is_full = false; break
		if is_full: lines_to_clear.append(y)
			
	if lines_to_clear.size() == 0: return 

	var player_y = int(round(logical_player_pos.y))
	if player_y in lines_to_clear:
		player.queue_free(); game_over("Spieler gesprengt!"); return

	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		if is_instance_valid(enemy):
			var enemy_y = int(round(enemy.logical_pos.y))
			if enemy_y in lines_to_clear:
				enemy.die(); enemies.remove_at(i)

	var chests_to_remove = []
	for pos in chests:
		if int(round(pos.y)) in lines_to_clear:
			chests_to_remove.append(pos)
	for pos in chests_to_remove:
		if is_instance_valid(chests[pos]):
			chests[pos].queue_free()
		chests.erase(pos)

	var new_grid_data = {}
	var new_grid_age = {}
	
	lines_to_clear.sort()
	for pos in grid_data:
		var y = int(round(pos.y))
		if y in lines_to_clear: continue
		var shift = 0
		for cleared_y in lines_to_clear:
			if cleared_y > y: shift += 1
		var new_pos = (pos + Vector2(0, shift)).snapped(Vector2(1, 1))
		
		new_grid_data[new_pos] = grid_data[pos]
		if grid_age.has(pos):
			new_grid_age[new_pos] = grid_age[pos]
			
	grid_data = new_grid_data
	grid_age = new_grid_age
	
	var p_shift = 0
	for cleared_y in lines_to_clear:
		if cleared_y > logical_player_pos.y: p_shift += 1
	if p_shift > 0:
		logical_player_pos = (logical_player_pos + Vector2(0, p_shift)).snapped(Vector2(1, 1))
		update_player_visuals()
		
	for enemy in enemies:
		if is_instance_valid(enemy):
			var e_shift = 0
			for cleared_y in lines_to_clear:
				if cleared_y > enemy.logical_pos.y: e_shift += 1
			if e_shift > 0:
				enemy.logical_pos = (enemy.logical_pos + Vector2(0, e_shift)).snapped(Vector2(1, 1))
				enemy.position = get_pixel_pos(enemy.logical_pos)
				enemy.z_index = int(enemy.logical_pos.y)
	
	var new_chests = {}
	for pos in chests:
		var y = int(round(pos.y))
		var shift = 0
		for cleared_y in lines_to_clear:
			if cleared_y > y: shift += 1
		
		var new_pos = (pos + Vector2(0, shift)).snapped(Vector2(1, 1))
		var chest_node = chests[pos]
		if is_instance_valid(chest_node):
			chest_node.position = get_pixel_pos(new_pos)
			chest_node.z_index = int(new_pos.y)
			new_chests[new_pos] = chest_node
	chests = new_chests


func update_dungeon_graphics():
	for node in wall_nodes.values(): if is_instance_valid(node): node.queue_free()
	wall_nodes.clear()
	for node in door_nodes.values(): if is_instance_valid(node): node.queue_free()
	door_nodes.clear()

	for pos in grid_data:
		var farbe = grid_data[pos]
		var w = wall_tile_scene.instantiate()
		add_child(w); move_child(w, 0)
		w.position = BOARD_OFFSET + (pos * TILE_SIZE)
		w.z_index = int(pos.y)
		
		var boden = w.get_node_or_null("BodenFarbe")
		
		if boden:
			if pos in revealed_cells:
				boden.color = COLORS[farbe] 
			else:
				boden.color = COLORS[farbe].darkened(0.5) 
		
		var hat_oben = (grid_data.has(pos + Vector2.UP) and grid_data[pos + Vector2.UP] == farbe) or is_door_open(pos, Vector2.UP)
		var hat_rechts = (grid_data.has(pos + Vector2.RIGHT) and grid_data[pos + Vector2.RIGHT] == farbe) or is_door_open(pos, Vector2.RIGHT)
		var hat_unten = (grid_data.has(pos + Vector2.DOWN) and grid_data[pos + Vector2.DOWN] == farbe) or is_door_open(pos, Vector2.DOWN)
		var hat_links = (grid_data.has(pos + Vector2.LEFT) and grid_data[pos + Vector2.LEFT] == farbe) or is_door_open(pos, Vector2.LEFT)
		
		var hat_oben_links = grid_data.has(pos + Vector2(-1, -1)) and grid_data[pos + Vector2(-1, -1)] == farbe
		var hat_oben_rechts = grid_data.has(pos + Vector2(1, -1)) and grid_data[pos + Vector2(1, -1)] == farbe
		var hat_unten_rechts = grid_data.has(pos + Vector2(1, 1)) and grid_data[pos + Vector2(1, 1)] == farbe
		var hat_unten_links = grid_data.has(pos + Vector2(-1, 1)) and grid_data[pos + Vector2(-1, 1)] == farbe
		
		var summe = 0
		
		if not hat_oben: summe += 1
		if not hat_rechts: summe += 2
		if not hat_unten: summe += 4
		if not hat_links: summe += 8
		
		if hat_oben and hat_links and not hat_oben_links: summe += 16
		if hat_oben and hat_rechts and not hat_oben_rechts: summe += 32
		if hat_unten and hat_rechts and not hat_unten_rechts: summe += 64
		if hat_unten and hat_links and not hat_unten_links: summe += 128
		
		var s = w.get_node_or_null("Sprite2D")
		if s: 
			if wand_tabelle.has(summe):
				s.frame = wand_tabelle[summe]
			else:
				s.frame = 0 
				
		wall_nodes[pos] = w

	for pos in doors:
		for dir in doors[pos]:
			var neighbor_pos = (pos + dir).snapped(Vector2(1, 1))
			
			if grid_age.has(pos) and grid_age.has(neighbor_pos):
				if grid_age[pos] < grid_age[neighbor_pos]:
					continue 

			var check_key = str(pos) + str(dir)
			if check_key in opened_doors:
				continue 

			var d = door_scene.instantiate()
			add_child(d)
			d.scale = Vector2(1.5, 1.5)
			var shift_amount = 8 
			
			d.position = BOARD_OFFSET + (pos * TILE_SIZE) + Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0)
			d.z_index = int(pos.y) 
			
			if dir == Vector2.DOWN:
				d.type = "bottom"
				d.position.y += shift_amount
			elif dir == Vector2.LEFT:
				d.type = "left"
				d.position.x -= shift_amount
			elif dir == Vector2.RIGHT:
				d.type = "right"
				d.position.x += shift_amount
			elif dir == Vector2.UP:
				d.queue_free(); continue

			d.play_idle()
			door_nodes[check_key] = d

# --- DUNGEON ARCHITEKT ---

func recalculate_dungeon_layout():
	var old_doors = doors.duplicate(true)
	doors.clear()
	
	var visited = [] 
	var rooms = [] 
	
	for key in grid_data.keys():
		var grid_pos = key.snapped(Vector2(1, 1))
		if has_point_in_list(visited, grid_pos): continue
		
		var current_room = []
		var color = grid_data[key]
		var stack = [grid_pos]
		visited.append(grid_pos)
		
		while stack.size() > 0:
			var current = stack.pop_back()
			current_room.append(current)
			
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var neighbor = (current + dir).snapped(Vector2(1, 1))
				if is_pos_in_grid_with_color(neighbor, color):
					if not has_point_in_list(visited, neighbor):
						visited.append(neighbor)
						stack.append(neighbor)
		rooms.append(current_room)
	
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var room_a = rooms[i]; var room_b = rooms[j]; var connections = []
			for pos_a in room_a:
				for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					var neighbor = (pos_a + dir).snapped(Vector2(1, 1))
					if has_point_in_list(room_b, neighbor): 
						connections.append([pos_a, dir])
			if connections.size() == 0: continue

			var existing_door_found = false
			for conn in connections:
				var pos = conn[0]; var dir = conn[1]
				var neighbor = (pos + dir).snapped(Vector2(1, 1))
				
				if old_doors.has(pos) and dir in old_doors[pos]:
					add_door(pos, dir); add_door(neighbor, -dir)
					existing_door_found = true; break 
				
				var open_key_here = str(pos) + str(dir)
				var open_key_there = str(neighbor) + str(-dir)
				if open_key_here in opened_doors or open_key_there in opened_doors:
					add_door(pos, dir); add_door(neighbor, -dir)
					existing_door_found = true; break 

			if not existing_door_found:
				var chosen = connections[int(connections.size() / 2.0)]
				add_door(chosen[0], chosen[1])
				add_door(chosen[0] + chosen[1], -chosen[1])

func has_point_in_list(liste, punkt):
	for p in liste:
		if p.distance_squared_to(punkt) < 0.1: return true
	return false

func is_pos_in_grid_with_color(pos, color):
	for k in grid_data:
		if k.distance_squared_to(pos) < 0.1:
			return grid_data[k] == color
	return false

func add_door(pos, dir):
	var clean_pos = pos.snapped(Vector2(1, 1))
	if not doors.has(clean_pos): doors[clean_pos] = []
	if not dir in doors[clean_pos]: doors[clean_pos].append(dir)

func is_door_open(from_pos, dir):
	var clean_pos = from_pos.snapped(Vector2(1, 1))
	return doors.has(clean_pos) and dir in doors[clean_pos]

func create_start_platform():
	var start_positions = [Vector2(4, 19), Vector2(5, 19)]
	for pos in start_positions:
		grid_data[pos] = 0; grid_age[pos] = 0
		if not pos in revealed_cells: revealed_cells.append(pos)
	recalculate_dungeon_layout(); update_dungeon_graphics()

# --- SPIELER BEWEGUNG ---

func try_move_player(dir):
	if is_game_over: return
	var target = logical_player_pos + dir
	if not grid_data.has(target): return 
	
	var enemy = get_enemy_at(target)
	if enemy and enemy.visible: return 
	
	var my_color = grid_data[logical_player_pos]
	var target_color = grid_data[target]
	
	if my_color != target_color:
		if is_door_open(logical_player_pos, dir):
			var door_key_here = str(logical_player_pos) + str(dir)
			var door_key_there = str(target) + str(-dir)
			
			var door_to_open = null
			if door_nodes.has(door_key_here): door_to_open = door_nodes[door_key_here]
			elif door_nodes.has(door_key_there): door_to_open = door_nodes[door_key_there]
			
			if door_to_open:
				door_to_open.open()
				if door_nodes.has(door_key_here): door_nodes.erase(door_key_here)
				if door_nodes.has(door_key_there): door_nodes.erase(door_key_there)
				opened_doors.append(door_key_here); opened_doors.append(door_key_there)
				reveal_room(target, target_color)
				end_player_turn(); return
		else:
			return 
	
	if chests.has(target):
		var chest_node = chests[target]
		if is_instance_valid(chest_node) and not chest_node.is_opened:
			chest_node.open_chest()
			var gold_found = 50 
			player_gold += gold_found
			ui_instance.update_gold(player_gold)
			
			chests.erase(target)
			end_player_turn()
			return 
	
	logical_player_pos = target
	update_player_visuals()
	reveal_room(logical_player_pos, grid_data[logical_player_pos])
	end_player_turn()

# --- AUFDECKEN ---
func reveal_room(start_pos, color):
	var visited = []
	var stack = [start_pos]
	var changes_made = false
	
	while stack.size() > 0:
		var current = stack.pop_back()
		if has_point_in_list(visited, current): continue
		visited.append(current)
		
		if not current in revealed_cells:
			revealed_cells.append(current)
			changes_made = true
		
		var enemy = get_enemy_at(current)
		if enemy: enemy.visible = true
		
		if chests.has(current):
			if is_instance_valid(chests[current]):
				chests[current].visible = true
			
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var neighbor = (current + dir).snapped(Vector2(1, 1))
			if is_pos_in_grid_with_color(neighbor, color):
				stack.append(neighbor)
	
	if changes_made: update_dungeon_graphics()

# --- KAMPF-MODUS UMSCHALTER ---
func toggle_attack_mode():
	attack_mode = !attack_mode
	player.modulate = Color.YELLOW if attack_mode else Color.WHITE

# --- KAMPF ---
func perform_attack(dir):
	if is_game_over: return
	
	input_locked = true
	player.last_direction = dir
	
	player.attack_visual()
	await get_tree().create_timer(0.4).timeout
	
	check_attack_hit()
	
	attack_mode = false
	player.modulate = Color.WHITE
	
	end_player_turn()
	input_locked = false

func check_attack_hit():
	var target_pos = logical_player_pos + player.last_direction
	var enemy = get_enemy_at(target_pos)
	if enemy and enemy.visible: 
		enemy.take_damage(1)
		
		if enemy.hp <= 0:
			enemies.erase(enemy)
		else:
			var push_target = enemy.logical_pos + player.last_direction
			if grid_data.has(push_target) and get_enemy_at(push_target) == null:
				if grid_data[enemy.logical_pos] == grid_data[push_target] or is_door_open(enemy.logical_pos, player.last_direction):
					var d_key = str(enemy.logical_pos) + str(player.last_direction)
					if not door_nodes.has(d_key): enemy.push_back(push_target, get_pixel_pos(push_target))

func end_player_turn():
	if player.hp <= 0: game_over("Vom Monster gefressen!"); return
	
	var hp_before = player.hp
	
	for enemy in enemies: 
		if is_instance_valid(enemy) and enemy.visible: 
			enemy.do_turn(logical_player_pos, player)
			enemy.z_index = int(enemy.logical_pos.y)
	
	if player.hp != hp_before:
		if ui_instance: ui_instance.update_health(player.hp, MAX_PLAYER_HP)

	if player.hp <= 0: game_over("Vom Monster gefressen!")

func update_player_visuals(): 
	player.move_visual(get_pixel_pos(logical_player_pos))
	player.z_index = int(logical_player_pos.y)

func get_pixel_pos(pos): return BOARD_OFFSET + (pos * TILE_SIZE) + Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0)
func get_enemy_at(pos):
	for e in enemies: if is_instance_valid(e) and e.logical_pos == pos: return e
	return null

func game_over(grund):
	print("GAME OVER: ", grund)
	is_game_over = true
	game_over_screen.visible = true
	
func _on_restart_pressed():
	is_game_over = false
	get_tree().reload_current_scene()
