extends Resource
class_name ItemData

# Hier ist deine exakte Liste! Das baut uns später ein cooles Dropdown-Menü.
enum ItemTyp { WAFFE, BOGEN, SCHILD, RING, HELM, RUESTUNG, STIEFEL, HANDSCHUHE }

@export var item_name: String = "Neues Item"
@export var typ: ItemTyp
@export var icon: Texture2D
@export var prefix: AffixData
@export var suffix: AffixData

@export_group("Basis-Werte")
@export var basis_atk: int = 0
@export var basis_def: int = 0
@export var basis_max_hp: int = 0
@export var basis_knockback: int = 0

@export_group("Beschreibung")
@export_multiline var beschreibung: String = ""

# Erzeugt ein praktisches Dropdown-Menü im Editor!
@export_enum("Waffe", "Rüstung", "Helm", "Schild", "Ring", "Bogen", "Stiefel", "Handschuhe", "Kein") var equip_slot: String = "Kein"

# Die Funktion für den magischen Namen
func get_item_name() -> String:
	var voller_name = item_name
	
	if prefix != null:
		voller_name = prefix.affix_name + " " + voller_name
		
	if suffix != null:
		voller_name = voller_name + " " + suffix.affix_name
		
	return voller_name
