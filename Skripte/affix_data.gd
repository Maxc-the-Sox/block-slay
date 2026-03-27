extends Resource
class_name AffixData

# Ist es eine Vorsilbe (Präfix) oder Nachsilbe (Suffix)?
enum AffixTyp { PRAEFIX, SUFFIX }

@export var affix_name: String = ""
@export var typ: AffixTyp

# Auf welche Items darf dieser Aufkleber geklebt werden?
@export var erlaubte_ausruestung: Array[ItemData.ItemTyp]

@export_group("Bonus-Werte")
@export var bonus_atk: int = 0
@export var bonus_def: int = 0
@export var bonus_max_hp: int = 0
@export var bonus_knockback: int = 0
