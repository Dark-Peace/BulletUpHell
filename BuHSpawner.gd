@tool
extends Node2D

signal bullet_collided_area(area:Area2D,area_shape_index:int, bullet:Dictionary,local_shape_index:int,shared_area:Area2D)
signal bullet_collided_body(body:Node,body_shape_index:int, bullet:Dictionary, local_shape_index:int,shared_area:Area2D)

const STANDARD_BULLET_RADIUS = 5

var CUSTOM:customFunctions = customFunctions.new()

@export var GROUP_BOUNCE:String = "Slime"

@export_group("Resource Lists")
@export var sfx_list:Array[AudioStream] = []
@export var rand_variation_list:Array[Curve] = []

@export_group("Optimisation Culling", "cull_")
@export var cull_bullets = true						# deletes bullets offscreen
@export var cull_except_for:String					# except for those props IDs
var no_culling_for = []
@export var cull_margin = STANDARD_BULLET_RADIUS*10	# distance from the viewport border after which culling is allowed
@export var cull_trigger = true						# desactivates triggers offscreen
@export var cull_partial_move = true				# continues to calculate position but doesn't move until onscreen
@export var cull_minimum_speed_required = 200		# bullet with speed under won't get culled
@export var cull_fixed_screen = false

##
var arrayProps:Dictionary = {}
var arrayTriggers:Dictionary = {}
var arrayPatterns:Dictionary = {}
var arrayContainers:Dictionary = {}
var arrayInstances:Dictionary = {}
@onready var textures = $ShapeManager.sprite_frames
@onready var arrayShapes = {} # format: id={shape, offset, rotation}
@onready var viewrect = get_viewport().get_visible_rect().grow(cull_margin)


var poolBullets:Dictionary = {}
var shape_indexes:Dictionary = {}
var shape_rids:Dictionary = {}
var Phys = PhysicsServer2D
enum BState{Unactive,Spawning,Spawned,Shooting,Moving,QueuedFree}
const UNACTIVE_ZONE = Vector2(99999,99999)

# pooling
var inactive_pool:Dictionary = {}

const ACTION_SPAWN = 0
const ACTION_SHOOT = 1
const ACTION_BOTH = 2
var poolQueue:Array = [] # format : [action:0=spawn1=shoot2=both, arraytospawn, arraytoshoot]
var poolTimes:Array = []
var loop_length = 9999
var time = 0
var next_in_queue

var RAND = RandomNumberGenerator.new()
var expression = Expression.new()
var _delta = 0
var HOMING_MARGIN = 20
enum GROUP_SELECT{Nearest_on_homing,Nearest_on_spawn,Nearest_on_shoot,Nearest_anywhen,Random}
enum SYMTYPE{ClosedShape,Line}
enum CURVE_TYPE{None,LoopFromStart,OnceThenDie,OnceThenStay,LoopFromEnd}
enum LIST_ENDS{Stop, Loop, Reverse}

var global_reset_counter:int = 0

## multithreading
var spawn_thread: Thread
var move_thread: Thread
var draw_thread: Thread


func _ready():
	if Engine.is_editor_hint(): return
	
	spawn_thread = Thread.new()
	move_thread = Thread.new()
	draw_thread = Thread.new()
	
	randomize()
	$ShapeManager.hide()
	for s in $ShapeManager.get_children():
		assert(s is CollisionShape2D or s is CollisionPolygon2D)
		if s.shape: arrayShapes[s.name] = [s.shape,s.position,s.rotation]
		s.queue_free()
	no_culling_for = cull_except_for.split(";",false)
	for a in $SharedAreas.get_children():
		assert(a is Area2D)
		a.connect("area_shape_entered",Callable(self,"bullet_collide_area").bind(a))
		a.connect("body_shape_entered",Callable(self,"bullet_collide_body").bind(a))
		a.set_meta("ShapeCount", 0)
	$Bouncy.global_position = UNACTIVE_ZONE
	var instance
	for s in sfx_list:
		instance = AudioStreamPlayer.new()
		instance.stream = s
		$SFX.call_deferred("add_child",instance)


func reset(minimal:bool=false):
	global_reset_counter += 1
	inactive_pool.clear()
	shape_indexes.clear()
	shape_rids.clear()
	poolBullets.clear()
	poolQueue.clear()
	poolTimes.clear()
	time = 0
	_delta = 0
	for a in $SharedAreas.get_children(): a.set_meta("ShapeCount", 0)
	$Bouncy.global_position = UNACTIVE_ZONE
	
	if not minimal:
		arrayContainers.clear()
		arrayInstances.clear()
		arrayPatterns.clear()
		arrayTriggers.clear()
		arrayProps.clear()
	else:
		for array in [arrayContainers, arrayInstances, arrayPatterns, arrayProps, arrayTriggers]:
			for elem in array.keys():
				if elem[0] == "@": continue
				array.erase(elem)

func _exit_tree():
	spawn_thread.wait_to_finish()
	draw_thread.wait_to_finish()
	move_thread.wait_to_finish()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return

	_delta = delta
	if not cull_fixed_screen:
		viewrect = Rect2(-get_canvas_transform().get_origin()/get_canvas_transform().get_scale(), \
						get_viewport_rect().size/get_canvas_transform().get_scale())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return

	if not poolBullets.is_empty():
#		if move_thread.is_started():
#			move_thread.wait_to_finish()
#		move_thread.start(bullet_movement.bind(delta))
#		#draw_thread.start(queue_redraw)
		bullet_movement(delta)
		queue_redraw()

	time += delta
	if time == loop_length: time = 0
	while not poolQueue.is_empty() and poolTimes[0] < time:
		next_in_queue = poolQueue[0]
		match next_in_queue[0]:
			ACTION_SPAWN: _spawn(next_in_queue[1])
			ACTION_SHOOT: _shoot(next_in_queue[1])
			ACTION_BOTH: _spawn_and_shoot(next_in_queue[1],next_in_queue[2])
		poolQueue.pop_front()
		poolTimes.pop_front()

func change_scene_to_file(file:String):
	reset_bullets()
	get_tree().change_scene_to_file(file)

func change_scene_to_packed(scene:PackedScene):
	reset_bullets()
	get_tree().change_scene_to_packed(scene)

func reset_bullets():
	clear_all_bullets()

func new_instance(id:String, instance:Node2D):
	if arrayInstances.has(id):
		push_warning("Warning : New instance ignored. Name "+id+" already exists. Make sure this duplicate isn't an error.")
		return
	arrayInstances[id] = instance
func new_trigger(id:String, t:RichTextEffect):
	if arrayTriggers.has(id):
		push_warning("Warning : New trigger ignored. Name "+id+" already exists. Make sure this duplicate isn't an error.")
		return
	arrayTriggers[id] = t
func new_pattern(id:String, p:NavigationPolygon):
	if arrayPatterns.has(id):
		push_warning("Warning : New pattern ignored. Name "+id+" already exists. Make sure this duplicate isn't an error.")
		return
	arrayPatterns[id] = p
func new_bullet(id:String, b:Dictionary):
	if arrayProps.has(id):
		push_warning("Warning : New bullet ignored. Name "+id+" already exists. Make sure this duplicate isn't an error.")
		return
	arrayProps[id] = b
func new_container(node):
	if arrayContainers.has(node.id):
		push_warning("Warning : New container ignored. Name "+node.id+" already exists. Make sure this duplicate isn't an error.")
		return
	arrayContainers[node.id] = node

func instance(id:String) -> Node2D:
	assert(arrayInstances.has(id), "Trying to get the scene instance named "+id+", which doesn't exist.")
	return arrayInstances[id]
func trigger(id:String):
	assert(arrayTriggers.has(id), "Trying to get the trigger "+id+", which doesn't exist.")
	return arrayTriggers[id]
func pattern(id:String):
	assert(arrayPatterns.has(id), "Trying to get the pattern "+id+", which doesn't exist.")
	return arrayPatterns[id]
func bullet(id:String):
	assert(arrayProps.has(id), "Trying to get the bulletprops "+id+", which doesn't exist.")
	return arrayProps[id]
func container(id:String):
	assert(arrayContainers.has(id), "Trying to get the trigger container "+id+", which doesn't exist.")
	return arrayContainers[id]



func create_pool(bullet:String, shared_area:String, amount:int, object:bool=false):
	var props:Dictionary = arrayProps[bullet]
	if not inactive_pool.has(bullet):
		inactive_pool[bullet] = []
		inactive_pool["__SIZE__"+bullet] = 0
	
	if object:
		for i in amount:
			inactive_pool[bullet].append(instance(props["instance_id"]).duplicate())
	else:
		var colID:String = props.get("anim_spawn_collision", props["anim_idle_collision"])
		var shared_rid:RID = get_shared_area_rid(shared_area)
		var count:int = Phys.area_get_shape_count(shared_rid)
		var new_rid:RID
		$SharedAreas.get_node(shared_area).set_meta("ShapeCount", $SharedAreas.get_node(shared_area).get_meta("ShapeCount",0)+amount) # Warning, bad sync possible ?
		for i in amount:
			new_rid = create_shape(shared_rid, colID, true, count+i)
#			shape_indexes[new_rid] = count+i
			_update_shape_indexes(new_rid, count+i, shared_area)
			inactive_pool[bullet].append([new_rid, shared_area])
	inactive_pool["__SIZE__"+bullet] += amount

# return RID for default bullets OR object reference for scenes
func wake_from_pool(bullet:String, queued_instance:Dictionary, shared_area:String, object:bool=false):
	if not inactive_pool.has(bullet):
		push_warning("WARNING : there's no bullet pool for bullet of ID "+bullet+" . Create a pool upon game load to avoid lag by calling Spawning.create_pool()")
		create_pool(bullet, queued_instance["shared_area"].name, 50, object) # TODO : 50 is arbitrary, there might be lag if it needs more
	elif inactive_pool[bullet].is_empty():
		push_warning("WARNING : bullet pool for bullet of ID "+bullet+" is empty. Create bigger one next time to avoid lag.")
		create_pool(bullet, queued_instance["shared_area"].name, max(inactive_pool["__SIZE__"+bullet]/10, 50), object)
	
	if inactive_pool[bullet][0] is Array:
		var i:int = 0
		while inactive_pool[bullet][i][1] != shared_area: i += 1
		var bID = inactive_pool[bullet].pop_at(i)[0]
		poolBullets[bID] = queued_instance
		return bID
	else:
		return inactive_pool[bullet].pop_at(0)

func back_to_grave(bullet:String, bID):
	inactive_pool[bullet].append([bID, poolBullets[bID]["shared_area"].name])
	poolBullets[bID]["state"] = BState.QueuedFree
	
	if bID is Node2D: bID.get_parent().remove_child(bID)

func set_angle(pattern:NavigationPolygon, pos:Vector2, queued_instance:Dictionary):
	if pattern.forced_target != NodePath():
		if pattern.forced_pattern_lookat: queued_instance["rotation"] = pos.angle_to_point(pattern.node_target.global_position)
		else: queued_instance["rotation"] = (pattern.node_target.global_position-queued_instance["spawn_pos"]).angle()
	elif pattern.forced_lookat_mouse:
		if pattern.forced_pattern_lookat: queued_instance["rotation"] = pos.angle_to_point(get_global_mouse_position())
		else: queued_instance["rotation"] = (pos+queued_instance["spawn_pos"]).angle_to_point(get_global_mouse_position())
	elif pattern.forced_angle != 0.0:
		queued_instance["rotation"] = pattern.forced_angle

func create_bullet_instance_dict(queued_instance:Dictionary, bullet_props:Dictionary, pattern:NavigationPolygon, l:int):
	queued_instance["shape_disabled"] = true
	if pattern.bullet in no_culling_for: queued_instance["no_culling"] = true
	queued_instance["speed"] = bullet_props.speed + pattern.layer_speed_offset*l
	queued_instance["vel"] = Vector2()
	if bullet_props.has("groups"): queued_instance["groups"] = bullet_props.get("groups")
	if pattern.follows_parent: queued_instance["follows_parent"] = true
	return queued_instance

func set_spawn_data(queued_instance:Dictionary, bullet_props:Dictionary, pattern:NavigationPolygon, l:int, i:int, ori_angle:float):
	var angle:float
	match pattern.resource_name:
		"PatternCircle":
			angle = (pattern.angle_total/pattern.nbr)*i + pattern.angle_decal + pattern.layer_pos_offset*l
			queued_instance["spawn_pos"] = Vector2(cos(angle)*pattern.radius,sin(angle)*pattern.radius).rotated(pattern.pattern_angle)
			queued_instance["rotation"] = angle + bullet_props.angle + pattern.layer_angle_offset*l + ori_angle
		"PatternLine":
			queued_instance["spawn_pos"] = Vector2(pattern.offset.x*(-abs(pattern.center-i-1))-pattern.nbr/2*pattern.offset.x, pattern.offset.y*i-pattern.nbr/2*pattern.offset.y).rotated(pattern.pattern_angle)
			queued_instance["rotation"] = bullet_props.angle + pattern.layer_angle_offset*l + pattern.pattern_angle + ori_angle
		"PatternOne":
			queued_instance["spawn_pos"] = Vector2()
			queued_instance["rotation"] = bullet_props.angle + pattern.layer_angle_offset*l + ori_angle
		"PatternCustomShape","PatternCustomPoints":
			queued_instance["spawn_pos"] = pattern.pos[i]
			queued_instance["rotation"] = bullet_props.angle + pattern.angles[i] + pattern.layer_angle_offset*l + ori_angle
		"PatternCustomArea":
			queued_instance["spawn_pos"] = pattern.pos[randi()%pattern.pooling][i]
			queued_instance["rotation"] = bullet_props.angle + ori_angle

func spawn(spawner, id:String, shared_area:String="0"):
	#spawn_thread.start(_thread_spawn.bind(spawner, id, shared_area))
	_thread_spawn(spawner, id, shared_area)

func _thread_spawn(spawner, id:String, shared_area:String="0"):
	assert(arrayPatterns.has(id))
	var local_reset_counter:int = global_reset_counter
	var bullets:Array
	var pattern:NavigationPolygon = arrayPatterns[id]
	var iter:int = pattern.iterations
	var shared_area_node = $SharedAreas.get_node(shared_area)

	var pos:Vector2; var ori_angle:float;
	var bullet_props:Dictionary; var queued_instance:Dictionary; var bID; var is_object:bool; var is_bullet_node:bool
	while iter != 0:
		for l in pattern.layer_nbr:
			if spawner is Node2D:
				ori_angle = spawner.rotation
				pos = spawner.global_position
			elif spawner is Dictionary:
				pos = spawner["position"]
				ori_angle = spawner["rotation"]
			else: push_error("spawner isn't a Node2D or a bullet RID")
			
			bullet_props = arrayProps[pattern.bullet]
			if bullet_props.get("has_random",false): bullet_props = create_random_props(bullet_props)
			
			is_object = bullet_props.has("instance_id")
			is_bullet_node = (is_object and bullet_props.has("speed"))
			for i in pattern.nbr:
				queued_instance = {}
				queued_instance["shared_area"] = shared_area_node
				queued_instance["props"] = bullet_props
				queued_instance["source_node"] = spawner
				queued_instance["state"] = BState.Unactive
				if not is_object:
					queued_instance["colID"] = bullet_props.get("anim_spawn_collision", bullet_props["anim_idle_collision"])
					queued_instance = create_bullet_instance_dict(queued_instance, bullet_props, pattern, l)
				elif is_bullet_node: queued_instance = create_bullet_instance_dict(queued_instance, bullet_props, pattern, l)
				
				set_spawn_data(queued_instance, bullet_props, pattern, l, i, ori_angle)
				
				if not bullet_props.get("fixed_rotation", false):
					set_angle(pattern, pos, queued_instance)
				else: queued_instance["rotation"] = 0
				
				if pattern.get("wait_tween_momentum") > 0:
					var tw_endpos = queued_instance["spawn_pos"]+pos+Vector2(pattern["wait_tween_length"], 0).rotated(PI+queued_instance["rotation"])
					queued_instance["momentum_data"] = [pattern["wait_tween_momentum"]-1, tw_endpos, pattern["wait_tween_time"]]
				
				bID = wake_from_pool(pattern.bullet, queued_instance, shared_area, is_object)
				bullets.append(bID)
				poolBullets[bID] = queued_instance
				
				if is_object:
					if is_bullet_node: bID.b = queued_instance
					
					if bullet_props.has("overwrite_groups"):
						for g in bID.get_groups():
							bID.remove_group(g)
					for g in bullet_props.get("groups", []):
						bID.add_to_group(g)
				
			_plan_spawning(pattern, bullets)
			
			if l < pattern.layer_nbr - 1: await get_tree().create_timer(pattern.layer_cooldown_spawn).timeout
		if iter > 0: iter -= 1
		await get_tree().create_timer(pattern.cooldown_spawn).timeout
		if local_reset_counter != global_reset_counter: return

func _plan_spawning(pattern:NavigationPolygon, bullets:Array):
	if pattern.cooldown_next_spawn == 0:
		_spawn(bullets)
		if pattern.cooldown_stasis: return
		var to_shoot = bullets.duplicate()
		if pattern.cooldown_next_shoot == 0:
			if pattern.cooldown_shoot == 0: _shoot(to_shoot) #no add pos
			else: plan_shoot(to_shoot, pattern.cooldown_shoot)
		else:
			var idx
			for b in to_shoot:
				idx = to_shoot.find(b)
				if pattern.symmetric:
					match pattern.symmetry_type:
						SYMTYPE.Line: plan_shoot([b], pattern.cooldown_shoot+(abs(pattern.center-idx))*pattern.cooldown_next_shoot)
						SYMTYPE.ClosedShape: plan_shoot([b], pattern.cooldown_shoot+(min(idx-pattern.center,to_shoot.size()-(idx-pattern.center)))*pattern.cooldown_next_shoot)
				else: plan_shoot([b], pattern.cooldown_shoot+idx*pattern.cooldown_next_shoot)
	else:
		var idx
		unactive_spawn(bullets)
		var to_spawn = bullets.duplicate()
		for b in to_spawn:
			idx = to_spawn.find(b)
			if pattern.symmetric:
				match pattern.symmetry_type:
					SYMTYPE.Line: plan_spawn([b], abs(pattern.center-idx)*pattern.cooldown_next_spawn)
					SYMTYPE.ClosedShape:
						plan_spawn([b], min(idx-pattern.center,to_spawn.size()-(idx-pattern.center))*pattern.cooldown_next_spawn)
			else: plan_spawn([b], idx*pattern.cooldown_next_spawn)
			
		if pattern.cooldown_stasis: return
		if pattern.cooldown_next_shoot == 0 and pattern.cooldown_shoot > 0:
			plan_shoot(to_spawn, pattern.cooldown_next_spawn*(to_spawn.size())+pattern.cooldown_shoot)
		elif pattern.cooldown_next_shoot == 0: #no add pos
			for b in to_spawn:
				idx = to_spawn.find(b)
				if pattern.symmetric:
					match pattern.symmetry_type:
						SYMTYPE.Line: plan_shoot([b], pattern.cooldown_shoot+(abs(pattern.center-idx))*pattern.cooldown_next_shoot)
						SYMTYPE.ClosedShape: plan_shoot([b], pattern.cooldown_shoot+(min(idx-pattern.center,to_spawn.size()-(idx-pattern.center)))*pattern.cooldown_next_shoot)
				else: plan_shoot([b], idx*pattern.cooldown_next_spawn)
		elif pattern.cooldown_shoot == 0:
			for b in to_spawn:
				idx = to_spawn.find(b)
				if pattern.symmetric:
					match pattern.symmetry_type:
						SYMTYPE.Line: plan_shoot([b], pattern.cooldown_shoot+(abs(pattern.center-idx))*pattern.cooldown_next_shoot)
						SYMTYPE.ClosedShape: plan_shoot([b], pattern.cooldown_shoot+(min(idx-pattern.center,to_spawn.size()-(idx-pattern.center)))*pattern.cooldown_next_shoot)
				else: plan_shoot([b], idx*(pattern.cooldown_next_shoot+pattern.cooldown_next_spawn))
		else:
			for b in to_spawn:
				idx = to_spawn.find(b)
				if pattern.symmetric:
					match pattern.symmetry_type:
						SYMTYPE.Line: plan_shoot([b], pattern.cooldown_shoot+(abs(pattern.center-idx))*pattern.cooldown_next_shoot)
						SYMTYPE.ClosedShape: plan_shoot([b], pattern.cooldown_shoot+(min(idx-pattern.center,to_spawn.size()-(idx-pattern.center)))*pattern.cooldown_next_shoot)
				else: plan_shoot([b], pattern.cooldown_next_spawn*(to_spawn.size())+pattern.cooldown_shoot+idx*pattern.cooldown_next_shoot)
	
	bullets.clear()


func create_shape(shared_rid:RID, ColID:String, init:bool=false, count:int=0) -> RID:
	var new_shape:RID
	var template_shape = arrayShapes[ColID][0]
	if template_shape is CircleShape2D:
		new_shape = Phys.circle_shape_create()
		Phys.shape_set_data(new_shape, template_shape.radius)
	elif template_shape is CapsuleShape2D:
		new_shape = Phys.capsule_shape_create()
		Phys.shape_set_data(new_shape, [template_shape.radius,template_shape.height])
	elif template_shape is ConcavePolygonShape2D:
		new_shape = Phys.concave_polygon_shape_create()
		Phys.shape_set_data(new_shape, template_shape.segments)
	elif template_shape is ConvexPolygonShape2D:
		new_shape = Phys.convex_polygon_shape_create()
		Phys.shape_set_data(new_shape, template_shape.points)
	elif template_shape is WorldBoundaryShape2D:
		new_shape = Phys.line_shape_create()
		Phys.shape_set_data(new_shape, [template_shape.d,template_shape.normal])
	elif template_shape is SeparationRayShape2D:
		new_shape = Phys.separation_ray_shape_create()
		Phys.shape_set_data(new_shape, [template_shape.length,template_shape.slide_on_slope])
	elif template_shape is RectangleShape2D:
		new_shape = Phys.rectangle_shape_create()
		Phys.shape_set_data(new_shape, template_shape.extents)
	elif template_shape is SegmentShape2D:
		new_shape = Phys.segment_shape_create()
		Phys.shape_set_data(new_shape, [template_shape.a,template_shape.b])

	Phys.area_add_shape(shared_rid, new_shape, \
		Transform2D(arrayShapes[ColID][2],arrayShapes[ColID][1]+(UNACTIVE_ZONE*int(init))))
	if count == 0: count = Phys.area_get_shape_count(shared_rid)
	Phys.area_set_shape_disabled(shared_rid, count-1, true)
	return new_shape


func plan_spawn(bullets:Array, spawn_delay:float=0):
	var timestamp = getKeyTime(spawn_delay)
	var insert_index = poolTimes.bsearch(timestamp)
	poolTimes.insert(insert_index, timestamp)
	poolQueue.insert(insert_index, [ACTION_SPAWN, bullets])

func plan_shoot(bullets:Array, shoot_delay:float=0):
	for b in bullets:
		if (not b is RID and not poolBullets[b]["props"].has("speed")): bullets.erase(b)
	
	var timestamp = getKeyTime(shoot_delay)
	var insert_index = poolTimes.bsearch(timestamp)
	poolTimes.insert(insert_index, timestamp)
	poolQueue.insert(insert_index, [ACTION_SHOOT, bullets])

func getKeyTime(delay):
	if loop_length < time+delay: return delay-(loop_length-time)
	else: return time+delay

func _spawn_and_shoot(to_spawn:Array, to_shoot:Array):
	_spawn(to_spawn)
	_shoot(to_shoot)

func unactive_spawn(bullets:Array):
	var B:Dictionary
	for b in bullets:
		assert(poolBullets.has(b))
		B = poolBullets[b]
		if B["state"] >= BState.Moving: continue
		if B["source_node"] is RID: B["position"] = B["spawn_pos"] + poolBullets[B["source_node"]]["position"]
		else: B["position"] = B["spawn_pos"] + B["source_node"].global_position

func _spawn(bullets:Array):
	var B:Dictionary
	for b in bullets:
		if not poolBullets.has(b):
			push_error("Warning: Bullet of ID "+str(b)+" is missing.")
			continue
		
		B = poolBullets[b]
		if B["state"] >= BState.Moving: continue
		if B["source_node"] is Dictionary: B["position"] = B["spawn_pos"] + B["source_node"]["position"]
		else: B["position"] = B["spawn_pos"] + B["source_node"].global_position
		if check_bullet_culling(B,b): continue
		
		if b is Node2D: # scene spawning
			_spawn_object(b, B)
			
		if b is RID or B["props"].has("speed"):
			if not change_animation(B,"spawn",b): B["state"] = BState.Spawning
			else: B["state"] = BState.Spawned
			if B["props"].has("anim_spawn_sfx"): $SFX.get_child(B["props"]["anim_spawn_sfx"]).play()
			
			init_special_variables(B,b)
			if B["props"].get("homing_select_in_group",-1) == GROUP_SELECT.Nearest_on_spawn:
				target_from_options(B)
		else: poolBullets.erase(b)

func _spawn_object(b:Node2D, B:Dictionary):
	b.global_position = B["spawn_pos"]
	b.rotation += B["rotation"]
	if b is CollisionObject2D:
		b.collision_layer = B["shared_area"].collision_layer
		b.collision_mask = B["shared_area"].collision_mask
	B["source_node"].call_deferred("add_child", b)

func use_momentum(pos:Vector2, B:Dictionary):
	B["position"] = pos

func _shoot(bullets:Array):
	var B:Dictionary
	for b in bullets:
		if not poolBullets.has(b): continue
		B = poolBullets[b]
		if (not b is RID and not B["props"].has("speed")):
			poolBullets.erase(b)
			continue
		if check_bullet_culling(B,b): continue
		
		if B.has("momentum_data"):
			var tween = get_tree().create_tween()
			tween.tween_method(use_momentum.bind(B), B["position"], B["momentum_data"][1], B["momentum_data"][2]).set_trans(B["momentum_data"][0])
		
		B["state"] = BState.Moving
		
		if B.get("follows_parent", false): B.erase("follows_parent")
		elif not B["props"].has("curve"): B.erase("spawn_pos")
		
		if B["props"].has("homing_target") or B["props"].has("node_homing"):
			if B["props"].get("homing_time_start",0) > 0:
				get_tree().create_timer(B["props"]["homing_time_start"]).connect("timeout",Callable(self,"_on_Homing_timeout").bind(B,true))
			else: _on_Homing_timeout(B, true)
		if B["props"].get("homing_select_in_group",-1) == GROUP_SELECT.Nearest_on_shoot:
			target_from_options(B)
		
		if not change_animation(B,"shoot",b): B["state"] = BState.Shooting
		if B["props"].has("anim_shoot_sfx"): $SFX.get_child(B["props"]["anim_shoot_sfx"]).play()
		

func init_special_variables(b:Dictionary, rid):
	var bp = b["props"]
	if bp.has("a_speed_multi_iterations"):
		b['speed_multi_iter'] = bp["a_speed_multi_iterations"]
		b['speed_interpolate'] = float(0)
	if bp.has("scale_multi_iterations"):
		b['scale_multi_iter'] = bp["scale_multi_iterations"]
		b['scale_interpolate'] = float(0)
	if bp.has("spec_bounces"):
		b['bounces'] = bp["spec_bounces"]
	if bp.has("a_direction_equation"):
		b['curve'] = float(0)
		b['curveDir_index'] = float(0)
	if bp.has("spec_modulate_loop"): b["modulate_index"] = float(0)
	if bp.has("spec_rotating_speed"): b["rot_index"] = float(0)
	if bp.has("spec_trail_length"):
		b["trail"] = [b["position"],b["position"],b["position"],b["position"]]
		b["trail_counter"] = float(0.0)
	if bp.has("homing_list"):
		b["homing_counter"] = int(0)
	if bp.has("curve"):
		b["curve_counter"] = float(0.0)
		if bp["a_curve_movement"] in [CURVE_TYPE.LoopFromStart,CURVE_TYPE.LoopFromEnd]:
			b["curve_start"] = bp["curve"].get_point_position(0)
	if bp.has("death_after_time"): b["death_counter"] = float(0.0)
	if bp.has("trigger_container"):
		b['trig_container'] = container(bp["trigger_container"])
		b["trigger_counter"] = int(0)
		var trig_types = b['trig_container'].getCurrentTriggers(b, rid)
		b['trig_types'] = trig_types
		b['trig_iter'] = {}
		if trig_types.has("TrigCol"): b["trig_collider"] = null
#		if trig_types.has("TrigPos"): b["trig_collider"] = null
		if trig_types.has("TrigSig"): b["trig_signal"] = null
		if trig_types.has("TrigTime"): b["trig_timeout"] = false

#	if bp.has("spec_rotating_speed"): b['bounces'] = bp["spec_rotating_speed"]
#	if bp.has("homing_target") or bp.has("homing_position"):
#		b['homing_target'] = bp["homing_target"]

func get_texture_frame(b:Dictionary, B, spriteframes:SpriteFrames=textures):
	if not b.has("anim_frame"): return spriteframes.get_frame_texture(b["texture"], 0)
	else:
		b["anim_counter"] += _delta
		if b["anim_counter"] >= 1/b["anim_speed"]:
			b["anim_counter"] = 0
			b["anim_frame"] += 1
			if b["anim_frame"] >= b["anim_length"]:
				if b["anim_loop"]:
					b["anim_frame"] = 0
				elif b["state"] == BState.Shooting:
					b["state"] = BState.Moving
					change_animation(b, "moving", B)
				elif b["state"] == BState.Spawning:
					b["state"] = BState.Spawned
					change_animation(b, "waiting", B)
		return spriteframes.get_frame_texture(b["texture"], b["anim_frame"])

func modulate_bullet(b:Dictionary, texture:Texture):
	if b["props"].has("spec_modulate_loop"):
		draw_texture(texture,-texture.get_size()/2,b["props"]["spec_modulate"].sample(b["modulate_index"]))
		b["modulate_index"] = b["modulate_index"]+(_delta/b["props"]["spec_modulate_loop"])
		if b["modulate_index"] >= 1: b["modulate_index"] = 0
	else: draw_texture(texture,-texture.get_size()/2,b["props"]["spec_modulate"].get_color(0))

func _draw():
	if Engine.is_editor_hint(): return
	
	var texture:Texture
	var b
	for B in poolBullets.keys():
		b = poolBullets[B]
		
		if B is Node2D:
			if b["props"].has("speed"): B.queue_redraw()
			if b.has("trail"):
				draw_set_transform(b["position"], b["rotation"]+b.get("rot_index",0),b.get("scale",Vector2(b["props"]["scale"],b["props"]["scale"])))
				for l in 3:
					draw_line(b["trail"][l],b["trail"][l+1],b["props"]["spec_trail_modulate"],b["props"]["spec_trail_width"])
			continue
			
		if (not (b["state"] >= BState.Spawning and viewrect.has_point(b["position"]))) or \
			(b["props"].has("spec_modulate") and b["props"].has("spec_modulate_loop") and \
			b["props"]["spec_modulate"].get_color(0).a == 0): continue
		
		texture = get_texture_frame(b, B)
		draw_set_transform_matrix(Transform2D(b["rotation"]+b.get("rot_index",0), b.get("scale",Vector2(b["props"]["scale"],b["props"]["scale"])),\
												b["props"].get("skew",0), b["position"]))
#		draw_set_transform(b["position"], b["rotation"]+b.get("rot_index",0),b.get("scale",Vector2(b["props"]["scale"],b["props"]["scale"])))
		
		if b.has("Beam"):
			draw_multiline(b["Beam"], Color.RED)
			
		elif b["props"].has("spec_modulate"):
			modulate_bullet(b, texture)
		else: draw_texture(texture,-texture.get_size()/2)
		
		if b.has("trail"):
			for l in 3:
				draw_line(b["trail"][l],b["trail"][l+1],b["props"]["spec_trail_modulate"],b["props"]["spec_trail_width"])

# type = "idle","spawn","waiting","delete"
func change_animation(b:Dictionary, type:String, B):
	var anim_id = b["props"].get("anim_"+type+"_texture","")
	var instantly = false
	if anim_id == "":
		anim_id = b["props"].get("anim_idle_texture")
		instantly = true
		
	if anim_id == null: return instantly
	b["texture"] = anim_id
	var frame_count = textures.get_frame_count(anim_id)
	if frame_count > 1:
		b["anim_length"] = frame_count
		b["anim_counter"] = 0
		b["anim_frame"] = 0
		b["anim_loop"] = textures.get_animation_loop(anim_id)
		b["anim_speed"] = textures.get_animation_speed(anim_id)
	elif b.has("anim_frame"):
		b.erase("anim_length")
		b.erase("anim_counter")
		b.erase("anim_frame")
		b.erase("anim_loop")
		b.erase("anim_speed")
	
	var col_id = b["props"].get("anim_"+type+"_collision","")
	if col_id != "" and col_id != b["colID"]:
		b["colID"] = col_id
		var new_rid:RID = create_shape(b["shared_area"].get_rid(), b["colID"])
		poolBullets[new_rid] = b
#		shape_indexes[new_rid] = Phys.area_get_shape_count(b["shared_area"].get_rid())-1
		_update_shape_indexes(new_rid, Phys.area_get_shape_count(b["shared_area"].get_rid())-1, b["shared_area"].name)
		back_to_grave(B["props"]["__ID__"], B)
	
	return instantly


enum CULLTYPE{Bullet,Move,Trigger}

func check_bullet_culling(B:Dictionary, rid):
	if not check_culling(B,CULLTYPE.Bullet): return
	delete_bullet(rid)
	return true

func check_move_culling(B:Dictionary):
	return check_culling(B,CULLTYPE.Move)

func check_trig_culling(B:Dictionary):
	return check_culling(B,CULLTYPE.Trigger)

func check_culling(B:Dictionary,type:int):
	if B["state"] in [BState.Unactive, BState.QueuedFree]: return false
	var can_cull
	match type:
		CULLTYPE.Bullet: can_cull = cull_bullets
		CULLTYPE.Move: can_cull = cull_partial_move
		CULLTYPE.Trigger: can_cull = cull_trigger
	return can_cull \
		and not viewrect.grow(cull_minimum_speed_required/B.get("speed", cull_minimum_speed_required)).abs().has_point(B["position"]) \
		and !B.get("no_culling", false)

func clear_all_bullets():
	for b in poolBullets.keys(): delete_bullet(b)

# TODO counts radius or not
func clear_bullets_within_dist(target_pos, radius:float=STANDARD_BULLET_RADIUS):
	for b in poolBullets.keys():
		if poolBullets[b]["position"].distance_to(target_pos) < radius:
			delete_bullet(b)

func clear_all_offscreen_bullets():
	for b in poolBullets.keys(): check_bullet_culling(poolBullets[b],b)

func delete_bullet(b):
	if not poolBullets.has(b): return
	var B = poolBullets[b]
	if B["props"].has("anim_delete_sfx"): $SFX.get_child(B["props"]["anim_delete_sfx"]).play()
	back_to_grave(B["props"]["__ID__"],b)

func get_bullets_in_radius(origin:Vector2, radius:float):
	var res:Array
	for b in poolBullets.keys():
		if poolBullets[b]["position"].distance_to(origin) < radius:
			res.append(b)
	return res

func get_shared_area_rid(shared_area_name:String):
	return $SharedAreas.get_node(shared_area_name).get_rid()

func get_shared_area(shared_area_name:String):
	return $SharedAreas.get_node(shared_area_name)

func change_shared_area(b:Dictionary, rid:RID, idx:int, new_area:Area2D):
	Phys.area_remove_shape(b["shared_area"].get_rid(),idx)
	Phys.area_add_shape(new_area.get_rid(), rid)
	b["shared_area"] = new_area
	_calculate_bullets_index()

func get_random_bullet():
	return poolBullets[randi()%poolBullets.size()]

func rid_to_bullet(rid):
	return poolBullets[rid]

func get_RID_from_index(source_area:RID, index:int) -> RID:
	return Phys.area_get_shape(source_area, index)

func change_property(type:String, id:String, prop:String, new_value):
	var res = call_deferred(type, id)
	match type:
		"pattern","container","trigger": res.set(prop, new_value)
		"bullet": res[prop] = new_value

func switch_property_of_bullet(b:Dictionary, new_props_id:String):
	b["props"] = bullet(new_props_id)

func switch_property_of_all(replaceby_id:String, replaced_id:String="__ALL__"):
	for b in poolBullets.values():
		if not (replaced_id == "__ALL__" or b["props"].hash() == bullet(replaced_id).hash()): continue
		b["props"] = bullet(replaceby_id)

func random_remove(id:String, prop:String):
	var res = bullet(id)
	res.remove_at(prop)

func random_change(type:String, id:String, prop:String, new_value):
	var res = call_deferred(type, id)
	match type:
		"pattern": res.set(prop,new_value)
		"bullet": res[prop] = new_value

func random_set(type:String, id:String, value:bool):
	var res = call_deferred(type, id)
	match type:
		"pattern": res.has_random = value
		"bullet": res["has_random"] = value

func add_group_to_bullet(b:Dictionary, group:String):
	if b.has("groups"): b["groups"].append(group)
	else: b["groups"] = [group]

func remove_group_from_bullet(b:Dictionary, group:String):
	if not b.has("groups"): return
	b["groups"].erase(group)

func clear_groups_from_bullet(b:Dictionary):
	b.erase("groups")

func is_bullet_in_group(b:Dictionary, group:String):
	if not b.has("groups"): return false
	return b["groups"].has(group)

func is_bullet_in_grouptype(b:Dictionary, grouptype:String):
	if not b.has("groups"): return false
	for g in b["groups"]:
		if not grouptype in g: continue
		return true

# call : get_variation(base_prop, v.x, v.y, v.z)
func get_variation(mean:float, variance:float, limit_down=0, limit_up=0):
	if limit_down != 0 and limit_up != 0:
		return min(max(RAND.randfn(mean,variance),limit_down), limit_up)
	elif limit_down != 0: return max(RAND.randfn(mean,variance),limit_down)
	elif limit_up != 0: return min(RAND.randfn(mean,variance),limit_up)
	else: return RAND.randfn(mean,variance)

func get_choice_string(list:String):
	var res:Array = list.split(";",false)
	return res[randi()%res.size()]

func get_choice_array(list:Array):
	return list[randi()%list.size()]

func edit_special_target(var_name:String, path:Node2D):
	set_meta("ST_"+var_name, path) # set path to null to remove_at meta variable

func get_special_target(var_name:String):
	return get_meta("ST_"+var_name)








# Bullet related functions

func ray_cast(bID):
	var b = poolBullets[bID]
	$RayCast2D.enabled = true
	$RayCast2D.global_position = b["position"]
	$RayCast2D.rotation = b["rotation"]
	$RayCast2D.target_position = Vector2(b["props"]["beam_length_per_ray"],0)
	$RayCast2D.collision_mask = b["shared_area"].collision_layer

	var array = []; var max_while = 0
	$RayCast2D.force_raycast_update()
	array.append(Vector2())
	while $RayCast2D.is_colliding() and max_while <= b["props"]["beam_bounce_amount"]:
		max_while += 1
		var pos = $RayCast2D.get_collision_point()
		var angle = $RayCast2D.get_collision_normal()
		if $RayCast2D.global_position.distance_to(pos) < 10:
			$RayCast2D.global_position += $RayCast2D.target_position.rotated($RayCast2D.rotation)/10
			continue
		else:
			$RayCast2D.rotation = angle.angle()
			$RayCast2D.global_position = pos + $RayCast2D.target_position.rotated($RayCast2D.rotation)/10
			array.append(pos-$RayCast2D.global_position)
			$RayCast2D.force_raycast_update()
	array.append($RayCast2D.target_position)#.rotated($RayCast2D.rotation))

	make_laser(array, b["props"]["beam_width"], b)

	$RayCast2D.collision_mask = 0
	$RayCast2D.global_position = UNACTIVE_ZONE
	$RayCast2D.enabled = false

func make_laser(points:Array, width:float, b:Dictionary):
	var array = []; var array2 = []; var angle
	for point in points.size():
		if point == points.size()-1: angle = points[point-1].angle_to_point(points[point])+PI/2
		elif point == 0: angle = points[point].angle_to_point(points[point+1])+PI/2
		else: angle = points[point-1].angle_to_point(points[point+1])+PI/2
		array.append(points[point]+Vector2(width,0).rotated(angle))
		array2.append(points[point]-Vector2(width,0).rotated(angle))
	array2.reverse()
	array.append_array(array2)
	b["Beam"] = PackedVector2Array(array)
#	Phys.shape_set_data(B, PackedVector2Array(array))






# movement functions
func move_scale(B:Dictionary, props, delta:float):
	if B.get("scale_multi_iter",0) == 0: return
	
	B["scale_interpolate"] += delta
	var _scale = props["scale"] * props["scale_multiplier"].sample(B["scale_interpolate"]/props["scale_multi_scale"])
	B["scale"] = Vector2(_scale,_scale)
	if B["scale_interpolate"]/props["scale_multi_scale"] >= 1 and props["scale_multi_iterations"] != -1:
		B["scale_multi_iter"] -= 1

func move_trail(B:Dictionary, props):
	if not B.has("trail_counter"): return
	
	B["trail_counter"] += _delta
	if B["trail_counter"] >= props["spec_trail_length"]:
		B["trail_counter"] = 0
		B["trail"].remove_at(3)
		B["trail"].insert(0, B["position"])

func move_speed(B:Dictionary, props, delta:float):
	if B.get("speed_multi_iter",0) == 0: return
	
	B["speed_interpolate"] += delta
	B["speed"] = props["a_speed_multiplier"].sample(B["speed_interpolate"]/props["a_speed_multi_scale"])
	if B["speed_interpolate"]/props["a_speed_multi_scale"] >= 1 and props["a_speed_multi_iterations"] != -1:
		B["speed_multi_iter"] -= 1

func move_equation(B:Dictionary, props):
	if props.get("a_direction_equation","") == "": return
	if expression.parse(props["a_direction_equation"],["x"]) != OK:
		push_error(expression.get_error_text())
		return
		
	B["curveDir_index"] += 0.05 #TODO add speed
	B["curve"] = expression.execute([B["curveDir_index"]])*100

func move_homing(B:Dictionary, props, delta:float):
	if not B.get("homing_target", null): return
	
	var target_pos:Vector2
	if typeof(B["homing_target"]) == TYPE_OBJECT:
		target_pos = B["homing_target"].global_position
	else: target_pos = B["homing_target"]
	
	if B["position"].distance_to(target_pos) < HOMING_MARGIN:
		if props.has("homing_list"):
			if B["homing_counter"] < props["homing_list"].size()-1:
				B["homing_counter"] += 1
				target_from_list(B)
			else:
				match props.get("homing_when_list_ends"):
					LIST_ENDS.Loop: B["homing_counter"] = 0
					LIST_ENDS.Reverse:
						B["homing_counter"] = 0
						props["homing_list"].reverse()
					LIST_ENDS.Stop:
						B["homing_target"] = null
		else: B["homing_target"] = null
	
	B["vel"] += ((target_pos-B["position"]).normalized()*B["speed"] - B["vel"]).normalized() * props["homing_steer"] * delta
	B["rotation"] = B["vel"].angle()

func move_curve(B:Dictionary, props, delta:float, b):
	B["position"] = B["spawn_pos"]+(props["curve"].sample_baked(B["curve_counter"]*B["speed"])-B["curve_start"]).rotated(B["rotation"])
	B["curve_counter"] += delta
	
	if B["curve_counter"] * B["speed"] < props["curve"].get_baked_length(): return
	match props["a_curve_movement"]:
		CURVE_TYPE.LoopFromStart: B["curve_counter"] = 0
		CURVE_TYPE.LoopFromEnd:
			B["curve_counter"] = 0
			B["spawn_pos"] = B["position"]
		CURVE_TYPE.OnceThenDie: delete_bullet(b)
		CURVE_TYPE.OnceThenStay: B["speed"] = 0


func bullet_movement(delta:float):
	var B:Dictionary; var props:Dictionary;
	for b in poolBullets.keys():
		B = poolBullets[b]
		
		if B["state"] == BState.Unactive: continue
		props = B["props"]
		if B["state"] == BState.QueuedFree:
			_apply_movement(B, b, props)
			continue
		
		if B.has("death_counter"):
			B["death_counter"] += delta
			if B["death_counter"] >= props["death_after_time"]:
				delete_bullet(b)
				_apply_movement(B, b, props)
				continue
		if props.has("beam_length_per_ray"): ray_cast(b)
		if B.has("rot_index"): B["rot_index"] += props["spec_rotating_speed"]
		
		#scale curve
		move_scale(B, props, delta)
		
		if B["state"] == BState.Spawned:
			if B["source_node"] is Dictionary: B["position"] = B["spawn_pos"] + B["source_node"]["position"]
			else: B["position"] = B["source_node"].global_position + B["spawn_pos"]
		
		elif B["state"] == BState.Moving:
			# trails
			move_trail(B, props)
			
			# speed curve
			move_speed(B, props, delta)
			
			# direction from math equation
			move_equation(B, props)
			
			# homing
			move_homing(B, props, delta)
				
			# follow path2D
			if props.get("curve"):
				move_curve(B, props, delta, b)
			else:
				B["vel"] = Vector2(B["speed"],B.get("curve",0)).rotated(B["rotation"])
				B["position"] += B["vel"]*delta
			
			if B.has("spawn_pos") and not props.has("curve"): B["position"] += B["spawn_pos"]
			
		# position triggers
		if B.has("trig_container") and B["trig_types"].has("TrigPos") \
			and (B["state"] == BState.Moving or not props["trigger_wait_for_shot"]) and not check_trig_culling(B):
				B["trig_container"].checkTriggers(B,b)
		
		# homing on nearest anywhen
		if props.get("homing_select_in_group",-1) == GROUP_SELECT.Nearest_anywhen:
			target_from_options(B)
		
		check_bullet_culling(B,b)
		
		if not b is RID:
			if b.base_scale == null: b.base_scale = b.scale
			# move object scene
			b.global_position = B["position"]
			b.rotation = B["rotation"] + B.get("rot_index",0)
			b.scale = b.base_scale * B.get("scale", Vector2(props["scale"], props["scale"]))
			continue
			
		_apply_movement(B, b, props)
		

func _apply_movement(B:Dictionary, b:RID, props:Dictionary):
	if B.get("state", BState.Unactive) == BState.Unactive or B.is_empty() or check_move_culling(B): return
	
	var shared_rid:RID = B["shared_area"].get_rid()
	var bullet_index:int = shape_indexes[b]
	# erase destroyed bullets
	if B["state"] == BState.QueuedFree:
		Phys.area_set_shape_disabled(shared_rid, bullet_index, true)
		poolBullets.erase(b)
		return
	
	# move shapes
	if not props.get("spec_no_collision", false):
		Phys.area_set_shape_transform(shared_rid, bullet_index, \
										Transform2D(B["rotation"]+B.get("rot_index",0), \
													B.get("scale",Vector2(props["scale"],props["scale"])), \
													props.get("skew",0), \
													B["position"]))
	# active collision for new bullets
	if B["shape_disabled"]:
		if not props.get("spec_no_collision", false):
			Phys.area_set_shape_disabled(shared_rid, shape_indexes[b], false)
		B["shape_disabled"] = false

func _calculate_bullets_index(from_index:int=-1):
	var shared_rid:RID; var Brid:RID; var B:Dictionary;
	if from_index == -1:
		for area in $SharedAreas.get_children():
			shared_rid = area.get_rid()
			for b_index in area.get_meta("ShapeCount"):
				Brid = get_RID_from_index(shared_rid,b_index)
				_update_shape_indexes(Brid, b_index, B["shared_area"].name)
				#shape_indexes[Brid] = b_index
#	else: # TODO : add optimisation
#		for index in shape_indexes.values():
#			if 

func _update_shape_indexes(rid, index:int, area:String):
	shape_indexes[rid] = index
	if not shape_rids.has(area):
		shape_rids[area] = {}
	shape_rids[area][index] = rid

func _on_Homing_timeout(B:Dictionary, start:bool):
	if start:
		var props = B["props"]
		if not props.has("homing_mouse"):
			if props.has("homing_target") or props.has("node_homing"): B["homing_target"] = props["node_homing"]
			else: B["homing_target"] = props["homing_position"]
		if props["homing_duration"] > 0:
			get_tree().create_timer(props["homing_duration"]).connect("timeout",Callable(self,"_on_Homing_timeout").bind(B,false))
		if props.get("homing_select_in_group",-1) == GROUP_SELECT.Nearest_on_homing:
			target_from_options(B)
		elif props.get("homing_select_in_group",-1) == GROUP_SELECT.Random:
			target_from_options(B,true)
		elif not B["props"].get("homing_list",[]).is_empty(): target_from_list(B)
	else:
		B["homing_target"] = Vector2()

func target_from_options(B:Dictionary, random:bool=false):
	if B["props"].has("homing_group"): target_from_group(B, random)
	elif B["props"].has("homing_surface"): target_from_segments(B, random)
	elif B["props"].has("homing_mouse"): B["homing_target"] = get_global_mouse_position()

func target_from_group(B:Dictionary, random:bool=false):
	var all_nodes = get_tree().get_nodes_in_group(B["props"]["homing_group"])
	if random:
		B["homing_target"] = all_nodes[randi()%all_nodes.size()]
		return
	var res:Node2D; var smaller_dist = INF; var curr_dist;
	for node in all_nodes:
		curr_dist = B["position"].distance_to(node.global_position)
		if curr_dist < smaller_dist:
			smaller_dist = curr_dist
			res = node
	B["homing_target"] = res

func target_from_segments(B:Dictionary, random:bool=false):
	var dist = INF; var res; var new_res; var new_dist
	for p in B["homing_surface"].size():
		new_res = Geometry2D.get_closest_point_to_segment(B["position"], B["homing_surface"][p], B["homing_surface"][(p+1)%B["homing_surface"].size()])
		new_dist = B["position"].distance_to(new_res)
		if new_dist < dist or (random and randi()%2 == 0):
			dist = new_dist
			res = new_res
	B["homing_target"] = res

func target_from_list(B:Dictionary, do:bool=true):
	if not do: return
	B["homing_target"] = B["props"]["homing_list"][B["homing_counter"]]

func trig_timeout(b, rid):
	if b is Node: b.trigger_timeout = true
	else:
		if check_trig_culling(b): return
		b["trig_timeout"] = true
	b.get("trig_container").checkTriggers(b,rid)




func bullet_collide_area(area_rid:RID,area:Area2D,area_shape_index:int,local_shape_index:int,shared_area:Area2D) -> void:
	############## uncomment if you want to use the standard behavior below ##############
#	var rid = shape_rids.get(shared_area.name, {}).get(local_shape_index)
	
	############## emit signal
#	if not poolBullets.has(rid): return
#	var B = poolBullets[rid]
#	bullet_collided_area.emit(area,area_shape_index,B,local_shape_index,shared_area)
	
	############## uncomment to manage trigger collisions with area collisions
#	if B["trig_types"].has("TrigCol"):
#		B["trig_collider"] = area
#		B["trig_container"].checkTriggers(B, rid)
	
	############## uncomment if you want to implement custom behavior
#	CUSTOM.bullet_collide_area(area_rid, area, area_shape_index, local_shape_index, shared_area, B, rid)
	pass

func bullet_collide_body(body_rid:RID,body:Node,body_shape_index:int,local_shape_index:int,shared_area:Area2D) -> void:
	var rid = shape_rids.get(shared_area.name, {}).get(local_shape_index)
	if not poolBullets.has(rid):
		rid = shared_area
		if not poolBullets.has(rid): return
	var B = poolBullets[rid]
	
#	if B["props"].has("spec_angle_no_collision"):
#		var angle:float = B["position"].angle_to_point(body.global_position)
	
	############## uncomment if you want to implement custom behavior
#	CUSTOM.bullet_collide_body(body_rid, body, body_shape_index, local_shape_index, shared_area, B, rid)
	
	bullet_collided_body.emit(body, body_shape_index, B, local_shape_index, shared_area)
	
	if B.get("bounces",0) > 0:
		bounce(B, shared_area)
		B["bounces"] = max(0, B["bounces"]-1)
	elif body.is_in_group(GROUP_BOUNCE): bounce(B, shared_area)
	
	if B.get("trig_types", []).has("TrigCol"):
		B["trig_collider"] = body
		B["trig_container"].checkTriggers(B, rid)
	
	if body.is_in_group("Player"):
		delete_bullet(rid)
	elif B["props"]["death_from_collision"]:
		delete_bullet(rid)

func bounce(B:Dictionary, shared_area:Area2D):
	if not B.has("colID"): return #TODO support custom bullet nodes
	$Bouncy/CollisionShape2D.shape = arrayShapes[B["colID"]][0]
	$Bouncy.collision_layer = shared_area.collision_layer
	$Bouncy.collision_mask = shared_area.collision_mask
	$Bouncy.global_position = B["position"]
	var collision = $Bouncy.move_and_collide(Vector2(0,0))
	if collision:
		B["vel"] = B["vel"].bounce(collision.normal)
		B["rotation"] = B["vel"].angle()
	$Bouncy/CollisionShape2D.shape = null
	$Bouncy.global_position = UNACTIVE_ZONE












## RANDOM VERSION

func create_random_props(original:Dictionary) -> Dictionary:
	var r_name:String; var res:Dictionary;
	var choice:Array; var variation:Vector3;
	for p in original.keys():
		r_name = match_rand_prop(p)
		if original.has(r_name+"_choice"):
			choice = original[r_name+"_choice"]
			variation = original.get(r_name+"_variation",Vector3(0,0,0))
			res[p] = get_variation(choice[randi()%choice.size()],variation.x,variation.y,variation.z)
		elif original.has(r_name+"_variation"):
			res[p] = get_variation(original[p],variation.x,variation.y,variation.z)
		elif original.has(r_name+"_chance"):
			res[p] = randf_range(0,1) < original[r_name+"_chance"]
	return res

func match_rand_prop(original:String) -> String:
	match original:
		"speed": return "r_speed"
		"scale": return "r_scale"
		"angle": return "r_angle"
		"groups": return "r_groups"
		"death_after_time": return "r_death_after"
		"anim_idle_texture": return "r_" #-----------------------
		"a_direction_equation": return "r_dir_equation"
		"curve": return "r_curve"
		"a_speed_multiplier": return "r_speed_multi_curve"
		"a_speed_multi_iterations": return "r_speed_multi_iter"
		"spec_bounces": return "r_bounce"
#		"spec_no_collision": return "r_"
		"spec_modulate": return "r_modulate"
		"spec_rotating_speed": return "r_rotating"
#		"spec_trail_length": return "r_"
#		"spec_trail_width": return "r_"
#		"spec_trail_modulate": return "r_"
		"trigger_container": return "r_trigger"
		"homing_target": return "r_homing_target"
		"homing_special_target": return "r_special_target"
		"homing_group": return "r_group_target"
		"homing_position": return "r_pos_target"
		"homing_steer": return "r_steer"
		"homing_duration": return "r_homing_dur"
		"homing_time_start": return "r_homing_delay"
#		"beam_length_per_ray": return "r_"
#		"beam_width": return "r_"
#		"beam_bounce_amount": return "r_"
		"scale_multiplier": return "r_scale_multi_curve"
		"scale_multi_iterations": return "r_scale_multi_iter"
		"": return "r_"
	return ""



