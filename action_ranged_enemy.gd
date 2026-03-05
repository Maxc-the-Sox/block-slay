extends CharacterBody2D

@export var max_hp: int = 2
@export var speed: float = 45.0 
@export var attack_range: float = 120.0 
@export var retreat_range: float = 60.0 

# ---> NEU: UNIVERSAL-GESCHOSS <---
# Hier kannst du im Inspektor reinziehen, was er schießen soll (Pfeil, Feuerball, Stein...)
@export var projectile_scene: PackedScene 

var current_hp: int
var player: Node2D = null
var last_direction: String = "down"

var is_attacking: bool = false
var is_dead: bool = false
var is_active: bool = false 

@onready var anim = $AnimatedSprite2D
@onready var shoot_point = $ShootPoint 

func _ready():
	current_hp = max_hp
	visible = false 
	if anim:
		anim.animation_finished.connect(_on_animation_finished)
	player = get_tree().get_first_node_in_group("Player")
	add_to_group("Enemies")

func wake_up():
	if is_dead: return
	is_active = true
	visible = true

func _physics_process(_delta):
	if is_dead or is_attacking or player == null or not is_active:
		return

	var distance = global_position.distance_to(player.global_position)
	var direction_to_player = global_position.direction_to(player.global_position)

	if distance <= attack_range and distance > retreat_range:
		_attack(direction_to_player)
	elif distance <= retreat_range:
		velocity = -direction_to_player * speed
		move_and_slide()
		_update_direction_string(direction_to_player) 
		_play_walk_anim()
	else:
		velocity = direction_to_player * speed
		move_and_slide()
		_update_direction_string(direction_to_player)
		_play_walk_anim()

func _attack(direction: Vector2):
	is_attacking = true
	velocity = Vector2.ZERO 
	_update_direction_string(direction)
	
	var anim_name = "attack_" + last_direction
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
	else:
		anim.play("idle_front")
	
	await get_tree().create_timer(0.4).timeout
	
	if not is_dead and is_instance_valid(player):
		_shoot_projectile(direction)

# ---> NEU: UMBENANNT IN PROJECTILE <---
func _shoot_projectile(direction: Vector2):
	if projectile_scene == null:
		print("FEHLER: Dieser Gegner hat kein Projektil im Inspektor zugewiesen bekommen!")
		return
		
	var proj = projectile_scene.instantiate()
	
	# ---> HIER WAR DER FEHLER! <---
	# FALSCH: get_tree().current_scene.add_child(proj)
	# RICHTIG: Wir fügen den Pfeil genau dort ein, wo das Skelett selbst ist!
	get_parent().add_child(proj) 
	
	if shoot_point:
		proj.global_position = shoot_point.global_position
	else:
		proj.global_position = global_position 
		
	proj.direction = direction
	proj.rotation = direction.angle()

func take_damage(amount: int):
	if is_dead: return
	current_hp -= amount
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	if current_hp <= 0:
		die()

func die():
	is_dead = true
	is_active = false
	velocity = Vector2.ZERO
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	var animation_zu_spielen = "die_front"
	if is_instance_valid(player):
		var richtung_vom_spieler = player.global_position.direction_to(global_position)
		if abs(richtung_vom_spieler.x) > abs(richtung_vom_spieler.y):
			animation_zu_spielen = "die_front"
			anim.flip_h = richtung_vom_spieler.x < 0
		else:
			if richtung_vom_spieler.y < 0: animation_zu_spielen = "die_back"
			else: animation_zu_spielen = "die_front"

	if anim.sprite_frames.has_animation(animation_zu_spielen):
		anim.play(animation_zu_spielen)
	else:
		queue_free()

func _update_direction_string(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		last_direction = "right" if direction.x > 0 else "left"
	else:
		last_direction = "down" if direction.y > 0 else "up"
	if not is_dead:
		anim.flip_h = false

func _play_walk_anim():
	var anim_name = "walk_" + last_direction
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
	elif anim.sprite_frames.has_animation("walk_down"):
		anim.play("walk_down")

func _on_animation_finished():
	if anim.animation.begins_with("attack_"):
		is_attacking = false 
	elif anim.animation.begins_with("die"):
		await get_tree().create_timer(3.0).timeout
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		await tween.finished
		queue_free()
