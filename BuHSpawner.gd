tool
extends AnimationPlayer

var bullet = preload("res://addons/BulletUpHell/BulletScene/BulletMob.tscn")

var arrayProps = {}
var arrayTriggers = {}
var arrayPatterns = {}
var arrayContainers = {}

var a:Animation = get_animation("Spawning")



func _ready():
	if not Engine.is_editor_hint():
		a.add_track(Animation.TYPE_METHOD, 0)
		a.track_set_path(0, self.get_path())
		a.add_track(Animation.TYPE_METHOD, 1)
		a.track_set_path(1, self.get_path())
		assigned_animation = "Spawning"



func new_trigger(id:String, t:RichTextEffect):
	assert(not arrayTriggers.has(id))
	arrayTriggers[id] = t
func new_pattern(id:String, p:NavigationPolygon):
	assert(not arrayPatterns.has(id))
	arrayPatterns[id] = p
func new_bullet(id:String, b:BulletProps):
	assert(not arrayProps.has(id))
	arrayProps[id] = b
func new_container(node):
	assert(not arrayContainers.has(node.id))
	arrayContainers[node.id] = node
	
func trigger(id:String):
	assert(arrayTriggers.has(id))
	return arrayTriggers[id]
func pattern(id:String):
	assert(arrayPatterns.has(id))
	return arrayPatterns[id]
func bullet(id:String) -> BulletProps :
	assert(arrayProps.has(id))
	return arrayProps[id]
func container(id:String):
	assert(arrayContainers.has(id))
	return arrayContainers[id]



func create_instance(pattern:NavigationPolygon):
	var instance
	if pattern.other_scene: instance = pattern.other_scene.instance()
	else:
		instance = bullet.instance()
		if pattern.bullet != null: instance.props_id = pattern.bullet
	return instance

func set_angle(pattern:NavigationPolygon, target:Node2D, instance):
	if pattern.forced_target != "":
		if pattern.forced_pattern_lookat: instance.rotation = target.get_angle_to(pattern.node_target.global_position)
		else: instance.rotation = (pattern.node_target.global_position-instance.global_position).angle()
	elif pattern.forced_angle != 0.0:
		instance.rotation = pattern.forced_angle


func spawn(target:Node2D, id:String):
	assert(arrayPatterns.has(id))
	var bullets:Array
	var pattern = arrayPatterns[id]
	var iter = pattern.iterations
	
	while iter != 0:
		for l in pattern.layer_nbr:
			var pos = target.global_position
			var ori_angle = target.rotation
			var bullet_props = arrayProps[pattern.bullet]
			match pattern.resource_name:
				"PatternCircle":
					for i in pattern.nbr:
						var instance = create_instance(pattern)
						instance.speed = bullet_props.speed + pattern.layer_speed_offset*l
						var angle = (pattern.angle_total/pattern.nbr)*i + pattern.angle_decal + pattern.layer_pos_offset*l
						var spawn_pos = Vector2(cos(angle)*pattern.radius,sin(angle)*pattern.radius).rotated(pattern.pattern_angle)#+pos
						instance.rotation = angle + bullet_props.angle + pattern.layer_angle_offset*l
						set_angle(pattern, target, instance)
						instance.spawn_pos = spawn_pos
						instance.source_node = target
						bullets.append(instance)
				"PatternLine":
					for i in pattern.nbr:
						var instance = create_instance(pattern)
						instance.speed = bullet_props.speed + pattern.layer_speed_offset*l
						var spawn_pos = Vector2(pattern.offset.x*(-abs(pattern.center-i-1))-pattern.nbr/2*pattern.offset.x, pattern.offset.y*i-pattern.nbr/2*pattern.offset.y).rotated(pattern.pattern_angle)
						instance.spawn_pos = spawn_pos#+pos
						instance.rotation = bullet_props.angle + pattern.layer_angle_offset*l + pattern.pattern_angle
						set_angle(pattern, target, instance)
						instance.source_node = target
						bullets.append(instance)
				"PatternOne":
					var instance = create_instance(pattern)
					instance.speed = bullet_props.speed + pattern.layer_speed_offset*l
#					instance.spawn_pos = pos
					instance.rotation = bullet_props.angle + pattern.layer_angle_offset*l
					set_angle(pattern, target, instance)
					instance.source_node = target
					bullets.append(instance)
				"PatternCustomShape":
					for i in pattern.nbr:
						var instance = create_instance(pattern)
						instance.speed = bullet_props.speed + pattern.layer_speed_offset*l
						var spawn_pos
						var pos_on_curve
						if pattern.closed_shape: pos_on_curve = pattern.shape.get_baked_length()/pattern.nbr*i
						else: pos_on_curve = pattern.shape.get_baked_length()/(pattern.nbr-1)*i
						spawn_pos = pattern.shape.interpolate_baked(pos_on_curve).rotated(pattern.pattern_angle)#+pos
						instance.spawn_pos = spawn_pos
						instance.rotation = pattern.angles[i] + pattern.layer_angle_offset*l
						set_angle(pattern, target, instance)
						instance.source_node = target
						bullets.append(instance)
			
			if pattern.cooldown_next_spawn == 0:
				if pattern.cooldown_next_shoot == 0:
					if pattern.cooldown_shoot == 0: #no add pos
						direct_spawn(bullets, target)
						for b in bullets:
#							b.
							b.shoot()
					else:
						var to_shoot = direct_spawn(bullets, target)
						plan_shoot(to_shoot, pattern.cooldown_shoot)
				else:
					var to_shoot = direct_spawn(bullets, target)
					for b in to_shoot:
						plan_shoot([b], pattern.cooldown_shoot+to_shoot.find(b)*pattern.cooldown_next_shoot)
			else:
				var to_spawn = direct_spawn(bullets, target, false)
				for b in to_spawn:
					plan_spawn([b], to_spawn.find(b)*pattern.cooldown_next_spawn)
				if pattern.cooldown_next_shoot == 0 and pattern.cooldown_shoot > 0:
					plan_shoot(to_spawn, pattern.cooldown_next_spawn*(to_spawn.size())+pattern.cooldown_shoot)
				elif pattern.cooldown_next_shoot == 0: #no add pos
					for b in to_spawn:
						plan_shoot([b], to_spawn.find(b)*pattern.cooldown_next_spawn)
				elif pattern.cooldown_shoot == 0:
					for b in to_spawn:
						plan_shoot([b], to_spawn.find(b)*(pattern.cooldown_next_shoot+pattern.cooldown_next_spawn))
				else: 
					for b in to_spawn:
						plan_shoot([b], pattern.cooldown_next_spawn*(to_spawn.size())+pattern.cooldown_shoot+to_spawn.find(b)*pattern.cooldown_next_shoot)
			
			bullets.clear()
			if l < pattern.layer_nbr-1: yield(get_tree().create_timer(pattern.layer_cooldown_spawn), "timeout")
		if iter > 0: iter -= 1
#		yield(get_tree().create_timer(pattern.cooldown_spawn+pattern.cooldown_shoot+pattern.nbr*(pattern.cooldown_next_spawn+pattern.cooldown_next_shoot)), "timeout")
		yield(get_tree().create_timer(pattern.cooldown_spawn), "timeout")
	

func direct_spawn(bullets:Array, target:Node2D, activated:bool=true):
	target = get_tree().current_scene
	var nbr_nodes = target.get_child_count()
	for i in bullets.size():
		target.add_child(bullets.pop_front())
		bullets.append(target.get_child(nbr_nodes+i))
		if not activated: target.get_child(nbr_nodes+i).activated = false
	return bullets.duplicate()

func plan_spawn(bullets:Array, spawn_delay:float=0):
	var key_data = getKeyTime(spawn_delay)
	var time = key_data[0]; var track = key_data[1];
	
	var key = a.track_find_key(track, time, true)
	if key > -1:
		var args:Array = a.method_track_get_params(track,key)
		args[0].append_array(bullets)
		a.track_insert_key(track, time, {"method": "_spawn_and_shoot", "args": args})
	else: a.track_insert_key(track, time, {"method": "_spawn_and_shoot", "args": [bullets,[]]})
	
	if current_animation != "Spawning" and a.track_get_key_count(0) > 0: play("Spawning")

func plan_shoot(bullets:Array, shoot_delay:float=0):
	var key_data = getKeyTime(shoot_delay)
	var time = key_data[0]; var track = key_data[1];
	
	var key = a.track_find_key(track, time, true)
	if key > -1:
		var args:Array = a.method_track_get_params(track,key)
		args[1].append_array(bullets)
		a.track_insert_key(track, time, {"method": "_spawn_and_shoot", "args": args})
	else: a.track_insert_key(track, time, {"method": "_spawn_and_shoot", "args": [[],bullets]})
	
	if current_animation != "Spawning" and a.track_get_key_count(0) > 0: play("Spawning")

func getKeyTime(delay):
	if a.length < current_animation_position+delay:
		return [delay-(a.length-current_animation_position), 1]
	else: return [current_animation_position+delay, 0]

func _spawn_and_shoot(to_spawn:Array, to_shoot:Array):
	_spawn(to_spawn)
	_shoot(to_shoot)

func _spawn(bullets:Array):
	for b in bullets: b.activated = true

func _shoot(bullets:Array):
	for b in bullets: b.shoot()


func reset_timeline(none):
	a.remove_track(0)
	a.add_track(Animation.TYPE_METHOD, 1)
	a.track_set_path(1, self.get_path())
	play("Spawning")



