extends CanvasLayer
@onready var sfx_bus_index = AudioServer.get_bus_index("Sfx")
@onready var music_bus_index = AudioServer.get_bus_index("Music")
const SAVE_PATH = "user://settings.cfg"

signal back_pressed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_settings()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func apply_volume_sfx(value: float):
	if value <= 0.01:
		AudioServer.set_bus_mute(sfx_bus_index, true)
	else:
		AudioServer.set_bus_mute(sfx_bus_index, false)
		AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(value))

func apply_volume_music(value: float):
	if value <= 0.01:
		AudioServer.set_bus_mute(music_bus_index, true)
	else:
		AudioServer.set_bus_mute(music_bus_index, false)
		AudioServer.set_bus_volume_db(music_bus_index, linear_to_db(value))

func _on_sfx_slider_value_changed(value: float) -> void:
	apply_volume_sfx(value)


func _on_music_slider_value_changed(value: float) -> void:
	apply_volume_music(value)


func _on_sfx_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		if has_node("TestSoundPlayer"):
			$TestSoundPlayer.play()


func _on_music_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		if has_node("TestSoundPlayer"):
			$TestSoundPlayer.play()
			
func save_settings():
	var config = ConfigFile.new()
	var current_db_sfx = AudioServer.get_bus_volume_db(sfx_bus_index)
	config.set_value("Audio", "sfx_volume", db_to_linear(current_db_sfx))
	var current_db_music = AudioServer.get_bus_volume_db(music_bus_index)
	config.set_value("Audio", "music_volume", db_to_linear(current_db_music))
	config.save(SAVE_PATH)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK:
	#	$SfxSlider.value = 0.8
	#	$MusicSlider.value = 0.8
		return
	var sfx_volume = config.get_value("Audio", "sfx_volume", 0.8)
	#$SfxSlider.value = sfx_volume
	apply_volume_sfx(sfx_volume)
	var music_volume = config.get_value("Audio", "music_volume", 0.8)
	#$MusicSlider.value = music_volume
	apply_volume_music(music_volume)


func _on_button_pressed() -> void:
	save_settings()
	emit_signal("back_pressed")


func _on_button_2_pressed() -> void:
	emit_signal("back_pressed")
