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

var wall_tile_scene = preload("res://walltile.tscn")
var wall_nodes = {} 

# TÜREN
var door_scene = preload("res://door.tscn")
var door_nodes = {}
var opened_doors = [] 

# UI Referenz
var ui_scene = preload("res://ui.tscn")
var ui_instance = null

var revealed_cells = []

var wand_tabelle = {
	# BLOCK A
	0: 0, 15: 14, 1: 19, 2: 11, 4: 5, 8: 13, 5: 26, 10: 10,
	3: 24, 6: 45, 12: 42, 9: 21, 7: 27, 14: 17, 13: 25, 11: 3,
	
	# BLOCK B
	16: 20, 32: 18, 64: 4, 128: 6,
	48: 1, 96: 9, 192: 15, 144: 7,
	80: 2, 160: 16,
	112: 36, 224: 29, 208: 30, 176: 37,
	240: 40,
	
	# BLOCK C
	65: 22, 129: 23, 193: 33,
	18: 38, 130: 31, 146: 41,
	20: 44, 36: 43, 52: 47,
	40: 35, 72: 28, 104: 39,
	
	# BLOCK D
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
var chest_scene = preload("res://chest.tscn") 

var enemies = [] # Hält ab jetzt nur noch Vector2-Koordinaten, keine echten Szenen mehr!
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
	
	# ---> NEU: Wir holen uns die echten HP aus dem Rucksack! <---
	player.hp = GlobalData.player_hp
	
	ui_instance.update_health(player.hp, GlobalData.player_max_hp)
	ui_instance.update_gold(player_gold)
	
	MusicManager.play_tetris()

func _process(delta):
	if is_game_over: return 
	
	fall_timer += delta
	if fall_timer >= fall_speed:
		fall_timer = 0
		move_piece(Vector2.DOWN)
	
	# Die Spieler-Steuerung (try_move_player) wurde hier entfernt!
	# Nur noch der Fall-Timer und das queue_redraw bleiben.
	
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
					
	# Zeichne auch die fixierten Monster-Icons
	for pos in enemies:
		var pixel_pos = BOARD_OFFSET + (pos * TILE_SIZE)
		var icon_size = Vector2(24, 24)
		var icon_pos = pixel_pos + Vector2(4, 4)
		draw_texture_rect(monster_icon, Rect2(icon_pos, icon_size), false)

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
	
	current_has_enemy = false
	current_has_chest = false
	
	var r = randf()
	if r < 0.2:
		current_has_enemy = true
	elif r < 0.3:
		current_has_chest = true

	if not is_valid_position(current_piece, current_pos):
		for p in current_piece:
			var final_pos = (current_pos + p).snapped(Vector2(1, 1))
			if final_pos.y >= 0 and final_pos.y < GRID_HEIGHT and final_pos.x >= 0 and final_pos.x < GRID_WIDTH:
				if not grid_data.has(final_pos):
					grid_data[final_pos] = current_color_idx
					grid_age[final_pos] = current_age
		
		current_piece = [] 
		recalculate_dungeon_layout()
		update_dungeon_graphics()
		queue_redraw() 
		
		await get_tree().create_timer(0.2).timeout 
		starte_action_dungeon()
		return
	
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
	if is_valid_position(new_shape, current_pos): 
		current_piece = new_shape
		# ---> NEU: SOUND FÜR DAS DREHEN <---
		if has_node("SfxRotate"):
			$SfxRotate.play()

func is_valid_position(shape, pos):
	for p in shape:
		var check = pos + p
		if check.x < 0 or check.x >= GRID_WIDTH or check.y >= GRID_HEIGHT: return false
		if grid_data.has(check): return false
	return true

func lock_piece():
	var hat_gleiche_farbe_beruehrt = false
	
	# 1. Wir scannen VORHER, ob wir Nachbarn gleicher Farbe haben
	for p in current_piece:
		var final_pos = (current_pos + p).snapped(Vector2(1, 1))
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var neighbor = final_pos + dir
			if grid_data.has(neighbor) and grid_data[neighbor] == current_color_idx:
				hat_gleiche_farbe_beruehrt = true
				
	# 2. Jetzt entscheiden wir, welcher Sound gespielt wird!
	if hat_gleiche_farbe_beruehrt:
		if has_node("SfxConnect"):
			$SfxConnect.play()
	else:
		if has_node("SfxLock"):
			$SfxLock.play()
			
	# 3. Danach ganz normal den Stein festkleben
	current_age += 1 
	var spawn_pos_special = Vector2.ZERO 
	
	for i in range(current_piece.size()):
		var p = current_piece[i]
		var final_pos = (current_pos + p).snapped(Vector2(1, 1))
		
		grid_data[final_pos] = current_color_idx
		grid_age[final_pos] = current_age 
		
		if i == 0: spawn_pos_special = final_pos
	
	if current_has_enemy:
		spawn_enemy(spawn_pos_special)
	elif current_has_chest:
		spawn_chest(spawn_pos_special)
	
	check_lines()
	recalculate_dungeon_layout()
	update_dungeon_graphics()
	
	spawn_new_piece()

# --- NEU: RUCKSACK PACKEN UND SZENE WECHSELN ---
func starte_action_dungeon():
	print("Decke erreicht! Phase 1: Rucksack packen...")
	
	GlobalData.tetris_grid = grid_data.duplicate()
	GlobalData.tetris_doors = doors.duplicate(true)
	GlobalData.truhen_positionen = chests.keys()
	
	GlobalData.monster_positionen.clear()
	for pos in enemies:
		GlobalData.monster_positionen.append(pos)
	
	print("Daten sind im Rucksack! Bereit für den Dungeon-Modus!")
	is_game_over = true 
	
	get_tree().change_scene_to_file("res://ActionDungeon.tscn")

# --- SPAWNER ---
func spawn_enemy(pos):
	# Wir merken uns nur noch die Position für später, spawnen aber keine 3D/2D Szene mehr!
	enemies.append(pos)

func spawn_chest(pos):
	var new_chest = chest_scene.instantiate()
	add_child(new_chest)
	new_chest.position = get_pixel_pos(pos)
	new_chest.visible = false
	new_chest.z_index = int(pos.y) 
	
	chests[pos] = new_chest

# --- STANDARDS ---

func check_lines():
	# ZEILENLÖSCHEN KOMPLETT DEAKTIVIERT
	return

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
		
		# FOG OF WAR ENTFERNT: Wir nutzen immer die helle Farbe
		if boden:
			boden.color = COLORS[farbe] 
		
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
			if wand_tabelle.has(summe): s.frame = wand_tabelle[summe]
			else: s.frame = 0 
				
		wall_nodes[pos] = w

	# Türen werden weiterhin normal gezeichnet
	for pos in doors:
		for dir in doors[pos]:
			var neighbor_pos = (pos + dir).snapped(Vector2(1, 1))
			if grid_age.has(pos) and grid_age.has(neighbor_pos):
				if grid_age[pos] < grid_age[neighbor_pos]: continue 
			var check_key = str(pos) + str(dir)
			if check_key in opened_doors: continue 
			var d = door_scene.instantiate()
			add_child(d)
			d.scale = Vector2(1.5, 1.5)
			d.position = BOARD_OFFSET + (pos * TILE_SIZE) + Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0)
			d.z_index = int(pos.y) 
			if dir == Vector2.DOWN: d.type = "bottom"; d.position.y += 8
			elif dir == Vector2.LEFT: d.type = "left"; d.position.x -= 8
			elif dir == Vector2.RIGHT: d.type = "right"; d.position.x += 8
			elif dir == Vector2.UP: d.queue_free(); continue
			d.play_idle()
			door_nodes[check_key] = d

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
	if not doors.has(clean_pos): 
		doors[clean_pos] = []
		
	if not dir in doors[clean_pos]: 
		doors[clean_pos].append(dir)

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
	pass # Keine Kämpfe mehr im Tetris!

# --- KAMPF ---
func perform_attack(_dir):
	pass # Keine Kämpfe mehr im Tetris!

func end_player_turn():
	if player.hp <= 0: game_over("Vom Monster gefressen!"); return
	
	# ---> NEU: Hier auch GlobalData nutzen <---
	if ui_instance: ui_instance.update_health(player.hp, GlobalData.player_max_hp)

func update_player_visuals(): 
	player.move_visual(get_pixel_pos(logical_player_pos))
	player.z_index = int(logical_player_pos.y)

func get_pixel_pos(pos): return BOARD_OFFSET + (pos * TILE_SIZE) + Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0)

func game_over(grund):
	print("GAME OVER: ", grund)
	is_game_over = true
	game_over_screen.visible = true
	
func _on_restart_pressed():
	is_game_over = false
	get_tree().reload_current_scene()
