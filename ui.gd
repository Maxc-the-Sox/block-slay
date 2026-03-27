extends CanvasLayer

# --- 1. BILDER & SKRIPTE LADEN ---
var heart_full = preload("res://assets/heart_full.png")
var heart_3quarter = preload("res://assets/heart_3quarter.png") 
var heart_half = preload("res://assets/heart_half.png")         
var heart_quarter = preload("res://assets/heart_quarter.png")   
var heart_empty = preload("res://assets/heart_empty.png")

var panel_small = preload("res://assets/Rpg Icon Pack/User Interface/Panels/panel 128x48.png")
var panel_large = preload("res://assets/Rpg Icon Pack/User Interface/Panels/panel 128x144.png")
var panel_square = preload("res://assets/Rpg Icon Pack/User Interface/Panels/panel 128x128.png")

var icon_empty_helm = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_helmet_empty.png")
var icon_empty_ring = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_ring_empty.png")
var icon_empty_waffe = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_weapon_empty.png")
var icon_empty_ruestung = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_chest_empty.png")
var icon_empty_schild = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_shield_empty.png")
var icon_empty_bogen = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_bow_empty.png")
var icon_empty_stiefel = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_boots_empty.png")
var icon_empty_handschuhe = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_gloves_empty.png")
var icon_empty_trank = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_potion_empty.png")
var icon_empty_inv = preload("res://assets/Rpg Icon Pack/User Interface/Inventory.character/inventory_empty.png")

var gold_icon_texture = preload("res://assets/gold_icon.png")
var slot_script = preload("res://Skripte/slot.gd")

# --- REFERENZEN ---
@onready var content_box = $MainPanel/ContentBox

var dynamic_health_container
var dynamic_equip_grid
var dynamic_potion_grid
var dynamic_main_inventory_grid 
var gold_label

# RECHTE SEITE REFERENZEN
var loot_window_bg 
var dynamic_loot_grid 
var char_stats_bg     # Charakterfenster
var item_detail_bg    # Item-Info-Fenster

# Text-Felder für die neuen Fenster
var label_stats_content
var label_item_name
var label_item_details

var currently_selected_slot = null
var active_chest = null 

# Grundwerte des Spielers (ohne Items)
@export var base_atk: int = 5
@export var base_def: int = 0

# --- NEU: Start-Items (Erscheinen rechts im Inspektor!) ---
@export var start_waffe: Resource
@export var start_ruestung: Resource

# --- NEU: Globale Werte für den Kampf & Anzeige ---
var current_total_atk: int = 5
var current_total_def: int = 0
var current_total_knockback: float = 15.0 # Basis-Wucht
var last_known_hp: int = 10      # Merkt sich die aktuellen HP für das Fenster
var last_known_max_hp: int = 10  # Merkt sich das Maximum für das Fenster

# Definition einer schönen braunen Farbe für Titel
var ui_brown = Color(0.4, 0.2, 0.0) # Dunkelbraun

func _ready():
	for child in content_box.get_children():
		child.hide()
		child.queue_free()
		
	build_custom_ui()
	
	# ---> NEU: Legt die Items direkt in die Ausrüstungsslots! <---
	_verteile_start_items()
	
	update_character_stats() # Einmal beim Start berechnen

# ==========================================
# HILFSFUNKTION: SMART KÄSTCHEN BAUEN
# ==========================================
func create_smart_slot(bg_texture, slot_name):
	var slot = TextureRect.new()
	slot.texture = bg_texture
	slot.custom_minimum_size = Vector2(48, 48)
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.set_script(slot_script)
	slot.slot_type = slot_name
	
	var item_layer = TextureRect.new()
	item_layer.name = "ItemIcon"
	item_layer.set_anchors_preset(Control.PRESET_FULL_RECT) 
	item_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	slot.add_child(item_layer)
	
	var border = ReferenceRect.new()
	border.name = "HighlightBorder"
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.editor_only = false 
	border.border_width = 3.0
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	border.hide()
	slot.add_child(border)
	
	slot.slot_clicked.connect(_on_slot_clicked)
	return slot

# ==========================================
# UI AUFBAU
# ==========================================
func build_custom_ui():
	content_box.add_theme_constant_override("separation", 6)
	
	# --- BLOCK 1: LEBEN (Wieder aufgeräumt!) ---
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
	
	# --- BLOCK 2: AUSRÜSTUNG ---
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
	var equip_layout = [null, icon_empty_helm, icon_empty_ring, icon_empty_waffe, icon_empty_ruestung, icon_empty_schild, icon_empty_bogen, icon_empty_stiefel, icon_empty_handschuhe]
	var equip_names = [null, "Helm", "Ring", "Waffe", "Rüstung", "Schild", "Bogen", "Stiefel", "Handschuhe"]
	for i in range(equip_layout.size()):
		if equip_layout[i] != null:
			dynamic_equip_grid.add_child(create_smart_slot(equip_layout[i], equip_names[i]))
		else:
			var empty = Control.new()
			empty.custom_minimum_size = Vector2(48, 48)
			dynamic_equip_grid.add_child(empty)
			
	# --- BLOCK 3: TRÄNKE ---
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
		dynamic_potion_grid.add_child(slot)
		
	# --- BLOCK 4: GOLD ---
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

	# --- BLOCK 5: INVENTAR ---
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
		dynamic_main_inventory_grid.add_child(create_smart_slot(icon_empty_inv, "Inv " + str(i)))


	# ==========================================
	# RECHTE SÄULE
	# ==========================================

	loot_window_bg = TextureRect.new()
	loot_window_bg.texture = panel_square
	loot_window_bg.custom_minimum_size = Vector2(192, 192)
	loot_window_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(loot_window_bg) 
	loot_window_bg.position = Vector2(608, 458) 
	var loot_center = CenterContainer.new()
	loot_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	loot_window_bg.add_child(loot_center)
	dynamic_loot_grid = GridContainer.new()
	dynamic_loot_grid.columns = 3 
	dynamic_loot_grid.add_theme_constant_override("h_separation", 6)
	dynamic_loot_grid.add_theme_constant_override("v_separation", 6)
	loot_center.add_child(dynamic_loot_grid)
	for i in range(9):
		dynamic_loot_grid.add_child(create_smart_slot(icon_empty_inv, "Loot " + str(i)))

	item_detail_bg = TextureRect.new()
	item_detail_bg.texture = panel_large
	item_detail_bg.custom_minimum_size = Vector2(192, 152)
	item_detail_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(item_detail_bg)
	item_detail_bg.position = Vector2(608, 300)
	var detail_vbox = VBoxContainer.new()
	detail_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	item_detail_bg.add_child(detail_vbox)
	
	label_item_name = Label.new()
	label_item_name.add_theme_color_override("font_color", ui_brown)
	label_item_name.add_theme_font_size_override("font_size", 13)
	label_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_item_name.add_theme_constant_override("line_spacing", -2)
	detail_vbox.add_child(label_item_name)
	
	label_item_details = Label.new()
	label_item_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_item_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_item_details.add_theme_font_size_override("font_size", 9) 
	label_item_details.add_theme_constant_override("line_spacing", -2)
	label_item_details.add_theme_color_override("font_color", Color.BLACK)
	detail_vbox.add_child(label_item_details)

	char_stats_bg = TextureRect.new()
	char_stats_bg.texture = panel_large
	char_stats_bg.custom_minimum_size = Vector2(192, 218)
	char_stats_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(char_stats_bg)
	char_stats_bg.position = Vector2(608, 76)
	var stats_vbox = VBoxContainer.new()
	stats_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	char_stats_bg.add_child(stats_vbox)
	
	var stats_title = Label.new()
	stats_title.text = "- Charakter -"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_title.add_theme_color_override("font_color", ui_brown)
	stats_vbox.add_child(stats_title)
	
	label_stats_content = Label.new()
	label_stats_content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_stats_content.add_theme_font_size_override("font_size", 12)
	label_stats_content.add_theme_constant_override("line_spacing", 4)
	label_stats_content.add_theme_color_override("font_color", Color.BLACK)
	stats_vbox.add_child(label_stats_content)

# ==========================================
# LOGIK: TAUSCHEN & VERSCHIEBEN
# ==========================================
func _on_slot_clicked(clicked_slot):
	var border = clicked_slot.get_node("HighlightBorder")
	
	if currently_selected_slot == null:
		if clicked_slot.current_item != null:
			currently_selected_slot = clicked_slot
			border.border_color = Color.YELLOW
			border.show()
			highlight_valid_slots(clicked_slot.current_item)
			update_item_details(clicked_slot.current_item)
	else:
		_move_item_logic(clicked_slot)

func _move_item_logic(clicked_slot):
	var source_slot = currently_selected_slot
	var item_to_move = source_slot.current_item
	
	if source_slot == clicked_slot:
		currently_selected_slot = null
		clear_all_highlights()
		return

	var is_valid_target = false
	if "slot_type" in clicked_slot:
		if clicked_slot.slot_type.begins_with("Inv ") or clicked_slot.slot_type.begins_with("Loot "):
			is_valid_target = true
		elif clicked_slot.slot_type == item_to_move.equip_slot:
			is_valid_target = true

	if is_valid_target:
		var item_im_ziel = clicked_slot.current_item
		var can_swap_back = true
		if item_im_ziel != null and "slot_type" in source_slot:
			if source_slot.slot_type.begins_with("Inv ") or source_slot.slot_type.begins_with("Loot "):
				can_swap_back = true 
			elif source_slot.slot_type != item_im_ziel.equip_slot:
				can_swap_back = false 

		if can_swap_back:
			clicked_slot.current_item = item_to_move
			clicked_slot.get_node("ItemIcon").texture = item_to_move.icon
			source_slot.current_item = item_im_ziel
			if item_im_ziel != null:
				source_slot.get_node("ItemIcon").texture = item_im_ziel.icon
			else:
				source_slot.get_node("ItemIcon").texture = null
			
			if clicked_slot.slot_type.begins_with("Loot ") or source_slot.slot_type.begins_with("Loot "):
				sync_chest_content()
			
			update_item_details(clicked_slot.current_item)
			update_character_stats()
		else:
			print("Tausch nicht möglich: Typen passen nicht zusammen.")
	
	currently_selected_slot = null
	clear_all_highlights()

# ==========================================
# TRUHEN-SYNCHRONISATION
# ==========================================
func sync_chest_content():
	if active_chest == null: return
	
	var new_content : Array[ItemData] = []
	for slot in dynamic_loot_grid.get_children():
		if slot.current_item != null:
			new_content.append(slot.current_item)
	
	active_chest.truhen_inhalt = new_content

func update_item_details(item):
	if item:
		label_item_name.text = split_text_smart(item.get_item_name())
		
		var info_text = "" 
		var gesamt_atk = item.basis_atk
		var gesamt_def = item.basis_def
		var gesamt_hp = item.basis_max_hp
		var gesamt_kb = item.basis_knockback
		
		if item.prefix:
			gesamt_atk += item.prefix.bonus_atk
			gesamt_def += item.prefix.bonus_def
			gesamt_hp += item.prefix.bonus_max_hp
			gesamt_kb += item.prefix.bonus_knockback
		if item.suffix:
			gesamt_atk += item.suffix.bonus_atk
			gesamt_def += item.suffix.bonus_def
			gesamt_hp += item.suffix.bonus_max_hp
			gesamt_kb += item.suffix.bonus_knockback
		
		if gesamt_atk > 0: info_text += "Angriff: +" + str(gesamt_atk) + "\n"
		if gesamt_def > 0: info_text += "Rüstung: +" + str(gesamt_def) + "\n"
		if gesamt_hp > 0: info_text += "Max HP: +" + str(gesamt_hp) + "\n"
		
		if item.beschreibung != "":
			var formatiert = split_text_smart(item.beschreibung)
			info_text += "\n---\n" + formatiert
			
		label_item_details.text = info_text
	else:
		label_item_name.text = "---"
		label_item_details.text = "Wähle ein Item aus..."

# ---> NEU: Zeigt Leben, Angriff und Verteidigung an! <---
func update_character_stats():
	var total_atk = base_atk
	var total_def = base_def
	var total_hp_bonus = 0
	var total_kb = 15.0 
	
	for slot in dynamic_equip_grid.get_children():
		if slot is TextureRect and slot.current_item != null:
			var item = slot.current_item
			total_atk += item.basis_atk
			total_def += item.basis_def
			total_hp_bonus += item.basis_max_hp
			total_kb += item.basis_knockback
			if item.prefix:
				total_atk += item.prefix.bonus_atk
				total_def += item.prefix.bonus_def
				total_hp_bonus += item.prefix.bonus_max_hp
				total_kb += item.prefix.bonus_knockback
			if item.suffix:
				total_atk += item.suffix.bonus_atk
				total_def += item.suffix.bonus_def
				total_hp_bonus += item.suffix.bonus_max_hp
				total_kb += item.suffix.bonus_knockback
				
	current_total_atk = total_atk
	current_total_def = total_def
	current_total_knockback = total_kb
	
	# Textaufbau für das Charakter-Fenster
	var stats_text = "Leben: " + str(last_known_hp) + " / " + str(last_known_max_hp) + "\n"
	stats_text += "Angriff: " + str(total_atk) + "\n"
	stats_text += "Verteidigung: " + str(total_def)
	
	# Zeigt optional den Bonus noch mal separat an
	if total_hp_bonus > 0:
		stats_text += "\n(Bonus Max HP: +" + str(total_hp_bonus) + ")"
		
	label_stats_content.text = stats_text

func highlight_valid_slots(item):
	for grid in [dynamic_main_inventory_grid, dynamic_equip_grid, dynamic_loot_grid]:
		for slot in grid.get_children():
			if "slot_type" in slot:
				var is_valid = false
				if slot.slot_type.begins_with("Inv") or slot.slot_type.begins_with("Loot"): is_valid = true
				elif slot.slot_type == item.equip_slot: is_valid = true
				if is_valid:
					var b = slot.get_node("HighlightBorder")
					b.border_color = Color.CYAN
					b.show()

func clear_all_highlights():
	for grid in [dynamic_main_inventory_grid, dynamic_equip_grid, dynamic_loot_grid]:
		for slot in grid.get_children():
			if slot.has_node("HighlightBorder"): slot.get_node("HighlightBorder").hide()

# ---> NEU: Aktualisiert auch das Stats-Fenster, wenn sich das Leben ändert <---
func update_health(current_hp, max_hp):
	last_known_hp = current_hp
	last_known_max_hp = max_hp
	
	# Wir rufen diese Funktion auf, damit sich die Zahl im Stats-Fenster anpasst!
	update_character_stats()
	
	if dynamic_health_container == null: return
	for child in dynamic_health_container.get_children(): child.queue_free()
		
	var total_hearts = 10
	var hp_per_heart = float(max_hp) / float(total_hearts) if max_hp > 0 else 0.0
	for i in range(total_hearts):
		var heart = TextureRect.new()
		heart.custom_minimum_size = Vector2(32, 32)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var heart_start_hp = i * hp_per_heart
		var heart_end_hp = (i + 1) * hp_per_heart
		if current_hp >= heart_end_hp: heart.texture = heart_full
		elif current_hp <= heart_start_hp: heart.texture = heart_empty
		else: heart.texture = heart_half
		dynamic_health_container.add_child(heart)

func update_gold(amount):
	if gold_label: gold_label.text = str(amount)

func fill_loot_window(gefundene_items: Array, chest_ref):
	active_chest = chest_ref
	if dynamic_loot_grid == null: return
	clear_loot_window()
	var slots = dynamic_loot_grid.get_children()
	for i in range(gefundene_items.size()):
		if i < slots.size():
			slots[i].get_node("ItemIcon").texture = gefundene_items[i].icon
			slots[i].current_item = gefundene_items[i]

func clear_loot_window():
	if dynamic_loot_grid == null: return
	for slot in dynamic_loot_grid.get_children():
		slot.get_node("ItemIcon").texture = null
		slot.current_item = null
		slot.get_node("HighlightBorder").hide()

func close_loot_window():
	clear_loot_window()
	active_chest = null 
	currently_selected_slot = null
	clear_all_highlights()
	update_item_details(null)

# ==========================================
# NEUE HILFSFUNKTION: TEXT INTELLIGENT TEILEN
# ==========================================
func split_text_smart(text: String) -> String:
	if text.length() <= 20: 
		return text
		
	if text.contains(","):
		var parts = text.split(",", true, 1) 
		return parts[0] + ",\n" + parts[1].strip_edges()
		
	var words = text.split(" ")
	if words.size() > 2:
		var mitte = words.size() / 2
		var zeile1 = " ".join(words.slice(0, mitte))
		var zeile2 = " ".join(words.slice(mitte))
		return zeile1 + "\n" + zeile2
		
	return text

# ==========================================
# START-ITEMS DIREKT AUSRÜSTEN
# ==========================================
func _verteile_start_items():
	# Wir packen alle Start-Items aus dem Inspektor in ein Array
	var start_items = [start_waffe, start_ruestung]
	
	# Gehe jedes Start-Item durch
	for item in start_items:
		if item != null:
			# Suche den passenden Slot im Ausrüstungs-Grid
			for slot in dynamic_equip_grid.get_children():
				if "slot_type" in slot and slot.slot_type == item.equip_slot:
					# Gefunden! Item direkt in den Ausrüstungsslot legen
					slot.current_item = item
					slot.get_node("ItemIcon").texture = item.icon
					break # Weiter zum nächsten Item
