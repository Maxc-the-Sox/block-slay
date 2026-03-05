extends Area2D

@export var speed: float = 300.0
@export var damage: int = 1

var direction: Vector2 = Vector2.ZERO

func _ready():
	# Wir sagen dem Pfeil: Pass auf, wenn du einen Körper (Body) berührst!
	body_entered.connect(_on_body_entered)
	
	# Wir sagen dem Pfeil: Sag Bescheid, wenn du aus dem Bildschirm fliegst!
	if has_node("VisibleOnScreenNotifier2D"):
		$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _physics_process(delta):
	# Der Pfeil fliegt jeden Frame in seine Richtung weiter
	position += direction * speed * delta

func _on_body_entered(body):
	print("Pfeil hat etwas berührt: ", body.name) # Godot sagt uns den Namen!

	if body.is_in_group("Enemies"):
		return
		
	if body.is_in_group("Player"):
		print("---> Das war der Spieler!")
		if body.has_method("take_damage"):
			print("---> Erteile ", damage, " Schaden!")
			body.take_damage(damage)
		else:
			print("---> FEHLER: Der Spieler hat keine take_damage() Funktion!")
	
	queue_free()

func _on_screen_exited():
	# Wenn der Pfeil ins Nirgendwo fliegt und den Bildschirm verlässt -> Löschen, um Speicher zu sparen
	queue_free()
