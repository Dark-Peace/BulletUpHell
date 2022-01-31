extends KinematicBody2D

export (String) var props_id = ""
var p:BulletProps
var source_node:Node2D
var spawn_pos:Vector2 = Vector2()

var trig_container
var trigger_counter:int = 0
var trig_types = []
var trig_iter = {}
var trig_timeout = false
var trig_collider
var trig_signal


var can_act = false
var vel = Vector2()
var speed
var bounces:int
#
var speed_interpolate:float = 0
var scale_interpolate:float = 0
var speed_multi_iter:int
var scale_multi_iter:int

var homing_target
var acc = Vector2()

var expression:Expression
var curveDir_index:float = 0
var curveAng_index:float = 0
var curve:float = 0


var activated:bool = true setget activate


func _ready():
	if not activated: return
	else: global_position = spawn_pos + source_node.global_position
	if props_id != "": p = Spawning.bullet(props_id)
	else:
		p = BulletProps.new()
		speed = p.speed
	
	scale = Vector2(p.scale, p.scale)
	
	speed_multi_iter = p.a_speed_multi_iterations
	scale_multi_iter = p.scale_multi_iterations
	bounces = p.spec_bounces
	
	if not p.mask in [0, 2]:
		p.shape = -1
		$Area2D.remove_from_group("Hitx1")
		scale = Vector2(1,1)
#
	if p.spec_ally:
		$Area2D.remove_from_group("Hitx1")
		$Area2D.add_to_group("Bullet_Partner") #todo
	#texture
	if p.shape == -1:
		$Sprite.texture = load("res://Assets/Sprites/Gui/MiniMasks.png")
		$Sprite.hframes = 23
		$Sprite.vframes = 1
		$Sprite.frame = p.mask
		$Area2D.add_to_group("Emo")
	elif p.shape == -2:
		$Area2D.remove_from_group("Hitx1")
		$Area2D.add_to_group("AngerHit")
		$Sprite.texture = load("res://Assets/Sprites/Attacks/AngerWave.png")
		$AnimationPlayer.play("Anger")
		$Sprite.vframes = 4
		$Sprite.hframes = 4
	else: $Sprite.frame = p.shape
#
#	#state
	for state in p.spec_states.keys(): if p.spec_states[state] > 0: add_effect(state)
	if p.spec_tourment: add_effect("Tourment")
	if p.spec_no_collision: $Area2D.remove_from_group("Hitx1")
#	else: $Area2D/CollisionShape2D.set_deferred("disabled", false)

	if p.a_direction_equation != "" or p.a_angular_equation != "": expression = Expression.new()
	
	if p.trigger_container:
		trig_container = Spawning.container(p.trigger_container)
		trig_types = trig_container.getCurrentTriggers(self)
		pass
	
func shoot():
	can_act = true
	if p.spec_top_level: set_as_toplevel(true)
	#timer
	if p.homing_time_start > 0:
		get_tree().create_timer(p.homing_time_start).connect("timeout", self, "_on_Homing_timeout", [true])
	else: _on_Homing_timeout(true)


func activate(value):
	if value and not activated:
		activated = value
		_ready()
	else: activated = value
	set_process(activated)
	# TODO add optimisation here
	if not activated: hide()
	else: show()
	

func _process(delta):
#	if p.spec_rotating_speed != 0: rotate(p.spec_rotating_speed)
	if can_act:
		#speed curve
		if speed_multi_iter != 0:
			speed_interpolate += delta
			speed = p.a_speed_multiplier.interpolate(speed_interpolate/p.a_speed_multi_scale)
			if speed_interpolate/p.a_speed_multi_scale >= 1 and p.a_speed_multi_iterations != -1:
				speed_multi_iter -= 1

		#scale curve
		if scale_multi_iter != 0:
			scale_interpolate += delta
			var _scale=p.scale*p.scale_multiplier.interpolate(scale_interpolate/p.scale_multi_scale)
			scale = Vector2(_scale,_scale)
			if scale_interpolate/p.scale_multi_scale >= 1 and p.scale_multi_iterations != -1:
				scale_multi_iter -= 1

		#direction from math equation
		if p.a_direction_equation != "":
			if expression.parse(p.a_direction_equation,["x"]) != OK:
				print(expression.get_error_text())
				return
			curveDir_index += 0.05
			curve = expression.execute([curveDir_index])*100
		
		#rotation from math equation
		if p.a_angular_equation != "":
			if expression.parse(p.a_angular_equation, ["x"]) != OK:
				print(expression.get_error_text())
				return
			curveAng_index += 0.005
			rotation += expression.execute([curveAng_index])
			
		#homing
		if homing_target:
			var target_angle:float
			var target_pos:Vector2
			if typeof(homing_target) == TYPE_OBJECT:
				target_pos = homing_target.global_position
				target_angle = get_angle_to(homing_target.global_position)
			else:
				target_pos = homing_target
				target_angle = get_angle_to(homing_target)
			if global_position.distance_to(target_pos) < 20: homing_target = null
			elif abs(target_angle) > speed/1000: rotation += p.homing_steer*sign(target_angle)
			
		vel = Vector2(speed,curve).rotated(rotation)
	else: global_position = spawn_pos + source_node.global_position
		
	# position triggers
	if (can_act or not p.trigger_wait_for_shot) and trig_types.has("TrigPos"):
		trig_container.checkTriggers(self)

	#collision
	var collision = move_and_collide(vel * delta)
	if collision:
		if (can_act or not p.trigger_wait_for_shot) and trig_types.has("TrigCol"):
			trig_collider = collision.collider
			trig_container.checkTriggers(self)
		
		if collision.collider.is_in_group("Slime") or bounces > 0 and can_act:
			vel = vel.bounce(collision.normal)
			rotation = vel.angle()
			bounces = max(0, bounces-1)
		elif collision.collider.is_in_group("Player"):
			$CollisionShape2D.set_deferred("disabled", true)
			$AnimationPlayer.play("Delete")
		else: call_deferred("queue_free")

func homing(target:Vector2):
	var desired = (target - global_position)*speed
	return (desired-vel).normalized() * p.homing_steer

func delete():
	pass
#	queue_free()
	
func anim():
	$AnimationPlayer.play("Life Countdown")
#
func add_effect(elem):
	add_to_group(elem)
#
#func check_random(prop):
#	if p.random.has(prop):
#		match typeof(p.get(prop)):
#			TYPE_INT: return GLOBAL.random_deviance(p.get(prop), p.random[prop])
#			TYPE_BOOL: 
#				if GLOBAL.rand(p.random[prop]): return !p.get(prop)
#				else: return p.get(prop)
#
func _on_Homing_timeout(start:bool):
	if start:
		if p.homing_target: homing_target = p.node_homing
		else: homing_target = p.homing_position
		if p.homing_duration > 0:
			get_tree().create_timer(p.homing_duration).connect("timeout", self, "_on_Homing_timeout", [false])
	else:
		homing_target = Vector2()

func triggerSignal(sig):
	trig_signal = sig
	trig_container.checkTriggers(self)

func trig_timeout():
	trig_timeout = true
	trig_container.checkTriggers(self)







func delete_audio(): pass






