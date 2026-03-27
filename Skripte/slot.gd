extends TextureRect

var current_item = null
var slot_type = ""

signal slot_clicked(clicked_slot)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("slot_clicked", self)
		accept_event() # <--- NEU: Frisst den Klick auf, damit er nicht zum Spieler durchgeht!
