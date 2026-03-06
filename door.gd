extends Node2D

@onready var anim = $AnimatedSprite2D

# Hier speichern wir, welcher Typ die Tür ist: "bottom", "left" oder "right"
# Das setzen wir später beim Spawnen im MainGame.
var type = "bottom" 

func _ready():
	# Sobald die Tür entsteht, zeigt sie ihren geschlossenen Zustand
	play_idle()

func play_idle():
	# Baut den Namen zusammen, z.B. "idle_bottom"
	var anim_name = "idle_" + type
	
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
	else:
		print("FEHLER: Tür-Animation fehlt: ", anim_name)

func open():
	# Baut den Namen zusammen, z.B. "open_bottom"
	var anim_name = "open_" + type
	
	# ---> NEU: SOUND ABSPIELEN <---
	if has_node("SfxOpen"):
		$SfxOpen.play()
	
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
		# Warten bis die Animation fertig ist
		await anim.animation_finished
		
	# ---> NEU: SICHERHEITSNETZ <---
	# Falls dein Sound länger dauert als die Animation, warten wir hier noch kurz ab!
	if has_node("SfxOpen") and $SfxOpen.playing:
		await $SfxOpen.finished
	
	# Und tschüss! Die Tür verschwindet logisch und grafisch.
	queue_free()
