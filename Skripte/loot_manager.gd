extends Node

# --- DIE BASIS-GEGENSTÄNDE ---
var basis_waffen: Array[ItemData] = [
	preload("res://GameData/Items/Waffen/Schwerter/bronzeschwert.tres"),
	preload("res://GameData/Items/Waffen/Schwerter/eisenschwert.tres"),
	preload("res://GameData/Items/Waffen/Schwerter/stahlschwert.tres")
]

var basis_ruestungen: Array[ItemData] = [
	preload("res://GameData/Items/Ruestungen/kettenhemd.tres"),
	preload("res://GameData/Items/Ruestungen/lederpanzer.tres"),
	preload("res://GameData/Items/Ruestungen/stofftunika.tres")
]

# --- DIE MAGISCHEN AFFIXE ---
var alle_praefixe: Array[AffixData] = [
	preload("res://GameData/Affixe/Praefixe/prefix_brutal.tres"),
	preload("res://GameData/Affixe/Praefixe/prefix_meister.tres"),
	preload("res://GameData/Affixe/Praefixe/prefix_rostig.tres"),
	preload("res://GameData/Affixe/Praefixe/prefix_scharf.tres"),
	preload("res://GameData/Affixe/Praefixe/prefix_wuchtig.tres")
]

var alle_suffixe: Array[AffixData] = [
	preload("res://GameData/Affixe/Suffixe/suffix_anfaenger.tres"),
	preload("res://GameData/Affixe/Suffixe/suffix_baer.tres"),
	preload("res://GameData/Affixe/Suffixe/suffix_krieger.tres"),
	preload("res://GameData/Affixe/Suffixe/suffix_riese.tres"),
	preload("res://GameData/Affixe/Suffixe/suffix_schildkroete.tres")
]

func generiere_zufalls_item() -> ItemData:
	var pool = basis_waffen + basis_ruestungen
	if pool.size() == 0: return null
		
	# 1. Basis-Item kopieren
	var neues_item = pool.pick_random().duplicate()
	
	# 2. Präfix auswürfeln (50% Chance)
	if randf() > 0.5 and alle_praefixe.size() > 0:
		neues_item.prefix = alle_praefixe.pick_random()
		# Hier könnten wir später Werte anpassen, z.B. neues_item.basis_atk += 2
		
	# 3. Suffix auswürfeln (50% Chance)
	if randf() > 0.5 and alle_suffixe.size() > 0:
		neues_item.suffix = alle_suffixe.pick_random()

	# 4. KLEINER BONUS-TRICK:
	# Falls du in deinen AffixData-Dateien auch Werte wie "bonus_atk" hast,
	# könntest du sie hier direkt auf das Item addieren. 
	# Aber für den Anfang reicht es, wenn die Basis-Werte aus der .tres Datei kommen!

	if neues_item.has_method("get_item_name"):
		print("Schmied fertig: ", neues_item.get_item_name())
	
	return neues_item
