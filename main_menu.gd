extends CanvasLayer
@onready var settings = $SettingsLayer
@onready var credits = $CreditsLayer
@onready var menu = $CenterContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	settings.back_pressed.connect(_on_settings_back)
	credits.back_pressed.connect(_on_credits_back)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if settings.visible:
			_on_settings_back()
		else:
			get_tree().quit()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main_game.tscn")


func _on_settings_button_pressed() -> void:
	settings.show()
	menu.hide()


func _on_credits_button_pressed() -> void:
	credits.show()
	menu.hide()
	
func _on_settings_back() -> void:
	settings.hide()
	menu.show()
	
func _on_credits_back() -> void:
	credits.hide()
	menu.show()
