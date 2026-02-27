extends CanvasLayer

# --- 1. HERZEN LADEN ---
var heart_full = preload("res://assets/heart_full.png")
var heart_3quarter = preload("res://assets/heart_3quarter.png") 
var heart_half = preload("res://assets/heart_half.png")         
var heart_quarter = preload("res://assets/heart_quarter.png")   
var heart_empty = preload("res://assets/heart_empty.png")

# --- 2. PANELS LADEN ---
var panel_small = preload("res://assets/Rpg Icon Pack/User Interface/Panels/panel 128x48.png")
var panel_large = preload("res://assets/Rpg Icon Pack/User Interface/Panels/panel 128x144.png")
# NEU: Quadratisches Panel für das Inventar
var panel_square = preload("res://assets/Rpg Icon Pack/User Interface/Panels/panel 128x128.png")

# --- 3. INVENTAR SILHOUETTEN LADEN ---
var icon_empty_helm = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_helmet_empty.png")
var icon_empty_ring = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_ring_empty.png")
var icon_empty_waffe = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_weapon_empty.png")
var icon_empty_ruestung = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_chest_empty.png")
var icon_empty_schild = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_shield_empty.png")
var icon_empty_bogen = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_bow_empty.png")
var icon_empty_stiefel = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_boots_empty.png")
var icon_empty_handschuhe = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_gloves_empty.png")
var icon_empty_trank = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_potion_empty.png")
# NEU: Standard Inventar Slot
var icon_empty_inv = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_empty.png")

var gold_icon_texture = preload("res://assets/gold_icon.png")

# --- REFERENZEN ---
@onready var content_box = $MainPanel/ContentBox

var dynamic_health_container
var dynamic_equip_grid
var dynamic_potion_grid
var dynamic_main_inventory_grid # NEU: Für die 9 Felder
var gold_label

func _ready():
	for child in content_box.get_children():
		child.hide()
		child.queue_free()
		
	build_custom_ui()

func build_custom_ui():
	# --- NEU: Den Abstand zwischen den 5 Blöcken exakt auf 6 Pixel setzen ---
	content_box.add_theme_constant_override("separation", 6)
	
	# ==========================================
	# BLOCK 1: LEBENSANZEIGE (192x72)
	# ==========================================
	var hp_bg = TextureRect.new()
	hp_bg.texture = panel_small
	hp_bg.custom_minimum_size = Vector2(192, 72)
	hp_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	content_box.add_child(hp_bg)
	
	var hp_center = CenterContainer.new()
	hp_center.set_anchors_preset(Control.PRESET_FULL_RECT) 
	hp_bg.add_child(hp_center)
	
	dynamic_health_container = GridContainer.new()
	dynamic_health_container.columns = 5
	dynamic_health_container.add_theme_constant_override("h_separation", 3) 
	dynamic_health_container.add_theme_constant_override("v_separation", 3)
	hp_center.add_child(dynamic_health_container)
	
	# ==========================================
	# BLOCK 2: AUSRÜSTUNG (Faktor 1.5x -> 192x218) <-- HIER SIND DIE +2 PIXEL
	# ==========================================
	var equip_bg = TextureRect.new()
	equip_bg.texture = panel_large
	equip_bg.custom_minimum_size = Vector2(192, 218) 
	equip_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	content_box.add_child(equip_bg)
	
	var equip_center = CenterContainer.new()
	equip_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	equip_bg.add_child(equip_center)
	
	dynamic_equip_grid = GridContainer.new()
	dynamic_equip_grid.columns = 3
	dynamic_equip_grid.add_theme_constant_override("h_separation", 6)
	dynamic_equip_grid.add_theme_constant_override("v_separation", 6)
	equip_center.add_child(dynamic_equip_grid)
	
	var equip_layout = [
		null, icon_empty_helm, icon_empty_ring,
		icon_empty_waffe, icon_empty_ruestung, icon_empty_schild,
		icon_empty_bogen, icon_empty_stiefel, icon_empty_handschuhe
	]
	
	var equip_names = [
		null, "Helm", "Ring",
		"Waffe", "Rüstung", "Schild",
		"Bogen", "Stiefel", "Handschuhe"
	]
	
	for i in range(equip_layout.size()):
		var slot = TextureRect.new()
		slot.custom_minimum_size = Vector2(48, 48)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		
		if equip_layout[i] != null:
			slot.texture = equip_layout[i]
			slot.set_meta("slot_type", equip_names[i])
			
		dynamic_equip_grid.add_child(slot)
		
	# ==========================================
	# BLOCK 3: TRÄNKE / EXTRAS (192x72)
	# ==========================================
	var potion_bg = TextureRect.new()
	potion_bg.texture = panel_small
	potion_bg.custom_minimum_size = Vector2(192, 72)
	potion_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	content_box.add_child(potion_bg)
	
	var potion_center = CenterContainer.new()
	potion_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	potion_bg.add_child(potion_center)
	
	dynamic_potion_grid = GridContainer.new()
	dynamic_potion_grid.columns = 3
	dynamic_potion_grid.add_theme_constant_override("h_separation", 12)
	potion_center.add_child(dynamic_potion_grid)
	
	for i in range(3):
		var slot = TextureRect.new()
		slot.texture = icon_empty_trank
		slot.custom_minimum_size = Vector2(48, 48)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.set_meta("slot_type", "Extra " + str(i+1))
		dynamic_potion_grid.add_child(slot)
		
	# ==========================================
	# BLOCK 4: GOLD (192x72)
	# ==========================================
	var gold_bg = TextureRect.new()
	gold_bg.texture = panel_small
	gold_bg.custom_minimum_size = Vector2(192, 72)
	gold_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	content_box.add_child(gold_bg)
	
	var gold_center = CenterContainer.new()
	gold_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	gold_bg.add_child(gold_center)
	
	var gold_hbox = HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 8)
	gold_center.add_child(gold_hbox)
	
	var g_icon = TextureRect.new()
	g_icon.texture = gold_icon_texture
	g_icon.custom_minimum_size = Vector2(36, 36)
	g_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_hbox.add_child(g_icon)
	
	gold_label = Label.new()
	gold_label.text = "0"
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color.BLACK) 
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_hbox.add_child(gold_label)

	# ==========================================
	# BLOCK 5: ALLGEMEINES INVENTAR (192x192)
	# ==========================================
	var inv_bg = TextureRect.new()
	inv_bg.texture = panel_square
	inv_bg.custom_minimum_size = Vector2(192, 192)
	inv_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	content_box.add_child(inv_bg)
	
	var inv_center = CenterContainer.new()
	inv_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_bg.add_child(inv_center)
	
	dynamic_main_inventory_grid = GridContainer.new()
	dynamic_main_inventory_grid.columns = 3 
	dynamic_main_inventory_grid.add_theme_constant_override("h_separation", 6)
	dynamic_main_inventory_grid.add_theme_constant_override("v_separation", 6)
	inv_center.add_child(dynamic_main_inventory_grid)
	
	for i in range(9):
		var slot = TextureRect.new()
		slot.texture = icon_empty_inv
		slot.custom_minimum_size = Vector2(48, 48)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.set_meta("slot_type", "Inv " + str(i))
		dynamic_main_inventory_grid.add_child(slot)


# --- LOGIK FUNKTIONEN ---

func update_health(current_hp, max_hp):
	if dynamic_health_container == null: return
	
	for child in dynamic_health_container.get_children():
		child.queue_free()
		
	var total_hearts = 10
	var hp_per_heart = 0.0
	if max_hp > 0:
		hp_per_heart = float(max_hp) / float(total_hearts)
	
	for i in range(total_hearts):
		var heart = TextureRect.new()
		# Die Herzen wieder in knackiger 32x32 Originalgröße
		heart.custom_minimum_size = Vector2(32, 32)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		
		var heart_start_hp = i * hp_per_heart
		var heart_end_hp = (i + 1) * hp_per_heart
		
		if hp_per_heart <= 0:
			heart.texture = heart_empty
		elif current_hp >= heart_end_hp:
			heart.texture = heart_full
		elif current_hp <= heart_start_hp:
			heart.texture = heart_empty
		else:
			var fraction = (float(current_hp) - heart_start_hp) / hp_per_heart
			if fraction > 0.75:
				heart.texture = heart_3quarter
			elif fraction > 0.50:
				heart.texture = heart_half
			else:
				heart.texture = heart_quarter
				
		dynamic_health_container.add_child(heart)

func update_gold(amount):
	if gold_label:
		gold_label.text = str(amount)
