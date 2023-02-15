@tool
extends Node2D

const STANDARD_BULLET_RADIUS = 5

## Optimisation culling
var cull_bullets = true						# deletes bullets offscreen
var cull_except_for:String					# except for those props IDs
var no_culling_for = []
var cull_margin = STANDARD_BULLET_RADIUS*10
var cull_trigger = true						# desactivates triggers offscreen
var cull_partial_move = true				# continues to calculate position but doesn't move until onscreen
var cull_minimum_speed_required = 200		# bullet with speed under won't get culled
var cull_fixed_screen = false

## Resource data
var sfx_list:Array[AudioStream] = []
var rand_variation_list:Array[Curve] = []

##
var arrayProps = {}
var arrayTriggers = {}
var arrayPatterns = {}
var arrayContainers = {}
@onready var textures = $ShapeManager.sprite_frames
@onready var arrayShapes = {} # format: id={shape, offset, rotation}
@onready var viewrect = get_viewport().get_visible_rect().grow(cull_margin)


var poolBullets = {}
var Phys = PhysicsServer2D
enum BState{Unactive,Spawning,Spawned,Shooting,Moving,QueuedFree}
# list of target nodes
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

#var FONT = Label.new().get_font("")


func _ready():
	if Engine.is_editor_hint(): return
	
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

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	_delta = delta
	if not cull_fixed_screen:
		viewrect = Rect2(-get_canvas_transform().get_origin()/get_canvas_transform().get_scale(), \
							get_viewport_rect().size/get_canvas_transform().get_scale())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	if not poolBullets.is_empty():
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


func new_trigger(id:String, t:RichTextEffect):
	assert(not arrayTriggers.has(id))
	arrayTriggers[id] = t
func new_pattern(id:String, p:NavigationPolygon):
	assert(not arrayPatterns.has(id))
	arrayPatterns[id] = p
func new_bullet(id:String, b:Dictionary):
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



func create_pool(bullet:String, shared_area:String, amount:int):
	var shared_rid:RID = get_shared_area_rid(shared_area)
	var colID:String = arrayProps[bullet].get("anim_spawn_collision", arrayProps[bullet]["anim_idle_collision"])
	if not inactive_pool.has(bullet):
		inactive_pool[bullet] = []
		inactive_pool["__SIZE__"+bullet] = 0
	for i in amount:
		inactive_pool[bullet].append([create_shape(shared_rid, colID), shared_area])
	inactive_pool["__SIZE__"+bullet] += amount

func wake_from_pool(bullet:String, queued_instance:Dictionary, shared_area:String):
	if inactive_pool[bullet].is_empty():
		push_warning("WARNING : bullet pool for bullet of ID "+bullet+" is empty. Create bigger one next time to avoid lag.")
		create_pool(bullet, queued_instance["shared_area"].name, max(inactive_pool["__SIZE__"+bullet]/10, 50))
		
	var i:int = 0
	while inactive_pool[bullet][i][1] != shared_area: i += 1
	var bID:RID = inactive_pool[bullet].pop_at(i)[0]
	poolBullets[bID] = queued_instance
	return bID

func back_to_grave(bullet:String, bID:RID):
	inactive_pool[bullet].append([bID, poolBullets[bID]["shared_area"].name])
	poolBullets.erase(bID)


func set_angle(pattern:NavigationPolygon, pos:Vector2, queued_instance:Dictionary):
	if pattern.forced_target != NodePath():
		if pattern.forced_pattern_lookat: queued_instance["rotation"] = pos.angle_to(pattern.node_target.global_position)
		else: queued_instance["rotation"] = (pattern.node_target.global_position-queued_instance["global_position"]).angle()
	elif pattern.forced_angle != 0.0:
		queued_instance["rotation"] = pattern.forced_angle

func spawn(target, id:String, shared_area="0"):
	assert(arrayPatterns.has(id))
	var bullets:Array
	var pattern = arrayPatterns[id]
	var iter = pattern.iterations
	var shared_area_node = $SharedAreas.get_node(shared_area)
	
	var pos:Vector2; var ori_angle:float;
	var bullet_props; var angle; var queued_instance; var bID;
	while iter != 0:
		for l in pattern.layer_nbr:
			if target is Node2D:
				ori_angle = target.rotation
				pos = target.global_position
			elif target is Dictionary:
				pos = target["position"]
				ori_angle = target["rotation"]
			else: push_error("target isn't a Node2D or a bullet RID")
			
			bullet_props = arrayProps[pattern.bullet]
			if bullet_props.get("has_random",false): bullet_props = create_random_props(bullet_props)
			shared_area_node.set_meta("ShapeCount", shared_area_node.get_meta("ShapeCount")+pattern.nbr) # Warning, bad sync possible ?
			for i in pattern.nbr:
				queued_instance = {}
				queued_instance["shared_area"] = shared_area_node
				queued_instance["colID"] = bullet_props.get("anim_spawn_collision", bullet_props["anim_idle_collision"])
				queued_instance["state"] = BState.Unactive
				queued_instance["props"] = bullet_props
				if pattern.bullet in no_culling_for: queued_instance["no_culling"] = true
				queued_instance["speed"] = bullet_props.speed + pattern.layer_speed_offset*l
				queued_instance["vel"] = Vector2()
				queued_instance["source_node"] = target
				if bullet_props.has("groups"): queued_instance["groups"] = bullet_props.get("groups")
				if pattern.follows_parent: queued_instance["follows_parent"] = true
				
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
				set_angle(pattern, pos, queued_instance)
				
				if pattern.get("wait_tween_momentum") > 0:
					var tw_endpos = queued_instance["spawn_pos"]+pos+Vector2(pattern["wait_tween_length"], 0).rotated(PI+queued_instance["rotation"])
					queued_instance["momentum_data"] = [pattern["wait_tween_momentum"]-1 ,tw_endpos, pattern["wait_tween_time"]]
					
				bID = wake_from_pool(pattern.bullet, queued_instance, shared_area)
				bullets.append(bID)
				poolBullets[bID] = queued_instance
			
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
			if l < pattern.layer_nbr-1: await get_tree().create_timer(pattern.layer_cooldown_spawn).timeout
		if iter > 0: iter -= 1
		await get_tree().create_timer(pattern.cooldown_spawn).timeout


func create_shape(shared_rid:RID, ColID:String, init:bool=false) -> RID:
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
	return new_shape
	
	# bullet base structure
#	{
#		"pID": 0,
#		"position": Vector2(),
#		"rotation": 0,
#		"state": BState.Unactive,
#	}

func plan_spawn(bullets:Array, spawn_delay:float=0):
	var timestamp = getKeyTime(spawn_delay)
	var insert_index = poolTimes.bsearch(timestamp)
	poolTimes.insert(insert_index,timestamp)
	poolQueue.insert(insert_index, [ACTION_SPAWN,bullets])

func plan_shoot(bullets:Array, shoot_delay:float=0):
	var timestamp = getKeyTime(shoot_delay)
	var insert_index = poolTimes.bsearch(timestamp)
	poolTimes.insert(insert_index,timestamp)
	poolQueue.insert(insert_index, [ACTION_SHOOT,bullets])

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
		#print("spawn ",b.get_id())
		if B["state"] >= BState.Moving: continue
		if B["source_node"] is RID: B["position"] = B["spawn_pos"] + poolBullets[B["source_node"]]["position"]
		else: B["position"] = B["spawn_pos"] + B["source_node"].global_position

func _spawn(bullets:Array):
#	for b in bullets:
#		print("to spawn ",b.get_id())
	var B:Dictionary
	for b in bullets:
		if not poolBullets.has(b):
			push_error("Warning: Bullet of RID "+b+" is missing.")
			continue
		#assert(poolBullets.has(b))
		B = poolBullets[b]
		if B["state"] >= BState.Moving: continue
		if B["source_node"] is Dictionary: B["position"] = B["spawn_pos"] + B["source_node"]["position"]
		else: B["position"] = B["spawn_pos"] + B["source_node"].global_position
		if check_bullet_culling(B,b): continue
		
		if not change_animation(B,"spawn",b): B["state"] = BState.Spawning
		else: B["state"] = BState.Spawned
		if B["props"].has("anim_spawn_sfx"): $SFX.get_child(B["props"]["anim_spawn_sfx"]).play()
		
		init_special_variables(B,b)
		if B["props"].get("homing_select_in_group",-1) == GROUP_SELECT.Nearest_on_spawn:
			target_from_options(B)
		#print(B["position"])

func use_momentum(pos:Vector2, B:Dictionary):
	B["position"] = pos

func _shoot(bullets:Array):
	var B:Dictionary
	for b in bullets:
		if not poolBullets.has(b): continue
		B = poolBullets[b]
		if check_bullet_culling(B,b): continue
		
		if B.has("momentum_data"):
			var tween = get_tree().create_tween()
			tween.tween_method(use_momentum.bind(B), B["position"], B["momentum_data"][1], B["momentum_data"][2]).set_trans(B["momentum_data"][0])
		
		B["state"] = BState.Moving
		
#		if not B.get("follows_parent", false):
#			B.erase("spawn_pos")
#		else: B.erase("follows_parent")
		if B.get("follows_parent", false): B.erase("follows_parent")
		elif not B["props"].has("curve"): B.erase("spawn_pos")
		
		if B["props"].has("homing_target") or B["props"].has("node_homing"):
			if B["props"].get("homing_time_start",0) > 0:
				get_tree().create_timer(B["props"]["homing_time_start"]).connect("timeout",Callable(self,"_on_Homing_timeout").bind(B,true))
			else: _on_Homing_timeout(B,true)
		if B["props"].get("homing_select_in_group",-1) == GROUP_SELECT.Nearest_on_shoot:
			target_from_options(B)
		elif not B["props"].get("homing_list",[]).is_empty(): target_from_list(B)
		
		if not change_animation(B,"shoot",b): B["state"] = BState.Shooting
		if B["props"].has("anim_shoot_sfx"): $SFX.get_child(B["props"]["anim_shoot_sfx"]).play()

func init_special_variables(b:Dictionary, rid:RID):
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


func _draw():
	if Engine.is_editor_hint(): return
	
	var texture
	var b
	for B in poolBullets.keys():
		b = poolBullets[B]
		if (not (b["state"] >= BState.Spawning and viewrect.has_point(b["position"]))) or \
			(b["props"].has("spec_modulate") and b["props"].has("spec_modulate_loop") and \
			b["props"]["spec_modulate"].get_color(0).a == 0): continue
		if b.has("anim_frame"):
			b["anim_counter"] += 1
			if b["anim_counter"] >= (1/_delta)/b["anim_speed"]:
				b["anim_frame"] += 1
				if b["anim_frame"] >= b["anim_length"]:
					if b["anim_loop"]: b["anim_frame"] = 0
					elif b["state"] == BState.Shooting:
						b["state"] = BState.Moving
						change_animation(b, "moving",B)
					elif b["state"] == BState.Spawning:
						b["state"] = BState.Spawned
						change_animation(b, "waiting",B)
			texture = textures.get_frame_texture(b["texture"],b["anim_frame"])
		else: texture = textures.get_frame_texture(b["texture"],0)
		
		draw_set_transform(b["position"], b["rotation"]+b.get("rot_index",0),b.get("scale",Vector2(b["props"]["scale"],b["props"]["scale"])))
		if b.has("Beam"):
			draw_multiline(b["Beam"], Color.RED)
		elif b["props"].has("spec_modulate"):
			if b["props"].has("spec_modulate_loop"):
				draw_texture(texture,-texture.get_size()/2,b["props"]["spec_modulate"].sample(b["modulate_index"]))
				b["modulate_index"] = b["modulate_index"]+(_delta/b["props"]["spec_modulate_loop"])
				if b["modulate_index"] >= 1: b["modulate_index"] = 0
			else: draw_texture(texture,-texture.get_size()/2,b["props"]["spec_modulate"].get_color(0))
		else: draw_texture(texture,-texture.get_size()/2)
		
		if b.has("trail"):
			for l in 3:
				draw_line(b["trail"][l],b["trail"][l+1],b["props"]["spec_trail_modulate"],b["props"]["spec_trail_width"])

# type = "idle","spawn","waiting","delete"
func change_animation(b:Dictionary, type:String, B:RID):
	var anim_id = b["props"].get("anim_"+type+"_texture","")
	var instantly = false
	if anim_id == "":
		anim_id = b["props"]["anim_idle_texture"]
		instantly = true
	b["texture"] = anim_id
	var frame_count = textures.get_frame_count(anim_id)
	if frame_count > 1:
		b["anim_length"] = frame_count
		b["anim_counter"] = 0
		b["anim_frame"] = 0
		b["anim_loop"] = textures.get_animation_loop(anim_id)
		b["anim_speed"] = textures.get_animation_speed(anim_id)
	
	var col_id = b["props"].get("anim_"+type+"_collision","")
	if col_id != "" and col_id != b["colID"]:
		b["colID"] = col_id
		poolBullets[create_shape(b["shared_area"].get_rid(), b["colID"])] = b
		poolBullets.erase(B)
		Phys.free_rid(B)
	
	return instantly


enum CULLTYPE{Bullet,Move,Trigger}

func check_bullet_culling(B:Dictionary, rid:RID):
	if not check_culling(B,CULLTYPE.Bullet): return
	delete_bullet(rid)
	return true

func check_move_culling(B:Dictionary):
	return check_culling(B,CULLTYPE.Move)
	
func check_trig_culling(B:Dictionary):
	return check_culling(B,CULLTYPE.Trigger)

func check_culling(B:Dictionary,type:int):
	if B["state"] == BState.Unactive: return false
	var can_cull
	match type:
		CULLTYPE.Bullet: can_cull = cull_bullets
		CULLTYPE.Move: can_cull = cull_partial_move
		CULLTYPE.Trigger: can_cull = cull_trigger
	return can_cull and not viewrect.grow(cull_minimum_speed_required/B["speed"]).abs().has_point(B["position"]) \
			and !B.get("no_culling",false)

func clear_all_bullets():
	for b in poolBullets.keys(): delete_bullet(b)

# TODO counts radius or not
func clear_bullets_within_dist(target_pos, radius:float=STANDARD_BULLET_RADIUS):
	for b in poolBullets.keys():
		if poolBullets[b]["position"].distance_to(target_pos) < radius:
			delete_bullet(b)

func clear_all_offscreen_bullets():
	for b in poolBullets.keys(): check_bullet_culling(poolBullets[b],b)

func delete_bullet(b:RID):
	var B = poolBullets[b]
	if B["props"].has("anim_delete_sfx"): $SFX.get_child(B["props"]["anim_delete_sfx"]).play()
	B["shared_area"].set_meta("ShapeCount", B["shared_area"].get_meta("ShapeCount")-1)
	back_to_grave(B["props"]["__ID__"],b)
#	poolBullets.erase(b)
#	Phys.free_rid(b)

func get_bullets_in_radius(origin:Vector2, radius:float):
	var res:Array
	for b in poolBullets.keys():
		if poolBullets[b]["position"].distance_to(origin) < radius:
			res.append(b)
	return res

func get_shared_area_rid(shared_area_name:String):
	return $SharedAreas.get_node(shared_area_name).get_rid()

func change_shared_area(b:Dictionary, rid:RID, idx:int, new_area:Area2D):
	Phys.area_remove_shape(b["shared_area"].get_rid(),idx)
	Phys.area_add_shape(new_area.get_rid(), rid)
	b["shared_area"] = new_area

func get_random_bullet():
	return poolBullets[randi()%poolBullets.size()]

func rid_to_bullet(rid:RID):
	return poolBullets[rid]

func get_RID_from_index(source_area:RID, index:int) -> RID:
	return Phys.area_get_shape(source_area,index)

func change_property(type:String, id:String, prop:String, new_value):
	var res = call_deferred(type, id)
	match type:
		"pattern","container","trigger": res.set(prop,new_value)
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
#	b["groups"] = []

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

func ray_cast(B:RID):
	var b = poolBullets[B]
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
	
	make_laser(array, B, b["props"]["beam_width"], b)
	
	$RayCast2D.collision_mask = 0
	$RayCast2D.global_position = UNACTIVE_ZONE
	$RayCast2D.enabled = false

func make_laser(points:Array, B:RID, width:float, b:Dictionary):
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

func bullet_movement(delta:float):
	var props
	var B:Dictionary;
	for b in poolBullets.keys():
		B = poolBullets[b]
		
		if B["state"] == BState.Unactive: continue
		props = B["props"]
		
		if B.has("death_counter"):
			B["death_counter"] += delta
			if B["death_counter"] >= props["death_after_time"]:
				delete_bullet(b)
				continue
		if props.has("beam_length_per_ray"): ray_cast(b)
		if B.has("rot_index"): B["rot_index"] += props["spec_rotating_speed"]
			
		#scale curve
		if B.get("scale_multi_iter",0) != 0:
			B["scale_interpolate"] += delta
			var _scale = props["scale"]*props["scale_multiplier"].sample(B["scale_interpolate"]/props["scale_multi_scale"])
			B["scale"] = Vector2(_scale,_scale)
			if B["scale_interpolate"]/props["scale_multi_scale"] >= 1 and props["scale_multi_iterations"] != -1:
				B["scale_multi_iter"] -= 1
				
		if B["state"] == BState.Spawned:
			if B["source_node"] is Dictionary: B["position"] = B["spawn_pos"] + B["source_node"]["position"]
			else: B["position"] = B["source_node"].global_position + B["spawn_pos"]
		elif B["state"] == BState.Moving:
			if B.has("trail_counter"):
				B["trail_counter"] += _delta
				if B["trail_counter"] >= props["spec_trail_length"]:
					B["trail_counter"] = 0
					B["trail"].remove_at(3)
					B["trail"].insert(0, B["position"])
				
			#speed curve
			if B.get("speed_multi_iter",0) != 0:
				B["speed_interpolate"] += delta
				B["speed"] = props["a_speed_multiplier"].sample(B["speed_interpolate"]/props["a_speed_multi_scale"])
				if B["speed_interpolate"]/props["a_speed_multi_scale"] >= 1 and props["a_speed_multi_iterations"] != -1:
					B["speed_multi_iter"] -= 1

			#direction from math equation
			if props.get("a_direction_equation","") != "":
				if expression.parse(props["a_direction_equation"],["x"]) != OK:
					print(expression.get_error_text())
					return
				B["curveDir_index"] += 0.05 #TODO add speed
				B["curve"] = expression.execute([B["curveDir_index"]])*100
			
			#homing
			if B.has("homing_target"):
				var target_angle:float
				var target_pos:Vector2
				if typeof(B["homing_target"]) == TYPE_OBJECT:
					target_pos = B["homing_target"].global_position
				else: target_pos = B["homing_target"]
				target_angle = B["position"].angle_to(target_pos)
				if B["position"].distance_to(target_pos) < HOMING_MARGIN:
					if props.has("homing_list"):
						if B["homing_counter"] < props["homing_list"].size()-1:
							B["homing_counter"] += 1
						else:
							match props.get("homing_when_list_ends"):
								LIST_ENDS.Loop: B["homing_counter"] = 0
								LIST_ENDS.Reverse:
									B["homing_counter"] = 0
									props["homing_list"].reverse()
								LIST_ENDS.Stop: B["homing_target"] = null
						target_from_list(B, false)
					else: B["homing_target"] = null
					
				B["vel"] += ((target_pos-B["position"]).normalized()*B["speed"]-B["vel"]).normalized()*props["homing_steer"]*delta
				B["vel"] = B["vel"].clamp(Vector2(0,0), Vector2(B["speed"],B["speed"]))
				B["rotation"] = B["vel"].angle()
			
			# follow path2D
			if props.get("curve"):
				B["position"] = B["spawn_pos"]+(props["curve"].sample_baked(B["curve_counter"]*B["speed"])-B["curve_start"]).rotated(B["rotation"])
				B["curve_counter"] += delta
				if B["curve_counter"]*B["speed"] >= props["curve"].get_baked_length():
					match props["a_curve_movement"]:
						CURVE_TYPE.LoopFromStart: B["curve_counter"] = 0
						CURVE_TYPE.LoopFromEnd:
							B["curve_counter"] = 0
							B["spawn_pos"] = B["position"]
						CURVE_TYPE.OnceThenDie: delete_bullet(b)
						CURVE_TYPE.OnceThenStay: B["speed"] = 0
			else:
				B["vel"] = Vector2(B["speed"],B.get("curve",0)).rotated(B["rotation"])
				B["position"] += B["vel"]*delta
			if B.has("spawn_pos") and not props.has("curve"): B["position"] += B["spawn_pos"]
			
		# position triggers
		if B.has("trig_container") and (B["state"] == BState.Moving or not props["trigger_wait_for_shot"]) \
			and not check_trig_culling(B) and B["trig_types"].has("TrigPos"):
				B["trig_container"].checkTriggers(B,b)
		
		check_bullet_culling(B,b)
		
	var shared_rid:RID
	for area in $SharedAreas.get_children():
		shared_rid = area.get_rid()
		for b in area.get_meta("ShapeCount"):
			if not poolBullets.has(get_RID_from_index(shared_rid,b)): continue
			B = poolBullets[get_RID_from_index(shared_rid,b)] # TODO change that for optimisation
			if B["state"] == BState.Unactive or check_move_culling(B): continue
			Phys.area_set_shape_transform(shared_rid, b,Transform2D(B["rotation"]+B.get("rot_index",0),B["position"]).scaled(B.get("scale",Vector2(props["scale"],props["scale"]))))
			

func _on_Homing_timeout(B:Dictionary, start:bool):
	if start:
		var props = B["props"]
		if props.has("homing_target") or props.has("node_homing"): B["homing_target"] = props["node_homing"]
		else: B["homing_target"] = props["homing_position"]
		if props["homing_duration"] > 0:
			get_tree().create_timer(props["homing_duration"]).connect("timeout",Callable(self,"_on_Homing_timeout").bind(B,false))
		if props.get("homing_select_in_group",-1) == GROUP_SELECT.Nearest_on_homing:
			target_from_options(B)
		elif props.get("homing_select_in_group",-1) == GROUP_SELECT.Random:
			target_from_options(B,true)
	else:
		B["homing_target"] = Vector2()

func target_from_options(B:Dictionary, random:bool=false):
	if B.has("homing_group"): target_from_group(B, random)
	elif B.has("homing_surface"): target_from_segments(B, random)

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

func trig_timeout(b:Dictionary, rid:RID):
	if check_trig_culling(b): return
	b["trig_timeout"] = true
	b["trig_container"].checkTriggers(b,rid)




func bullet_collide_area(area_rid:RID,area:Area2D,area_shape_index:int,local_shape_index:int,shared_rid:RID) -> void:
	pass
#	if (can_act or not p.trigger_wait_for_shot) and trig_types.has("TrigCol"):
#		trig_collider = collision.collider
#		trig_container.checkTriggers(self)
	
func bullet_collide_body(body_rid:RID,body:Node,body_shape_index:int,local_shape_index:int,shared_area:Area2D) -> void:
	var rid = get_RID_from_index(shared_area.get_rid(), local_shape_index)
	if not poolBullets.has(rid): return
	var B = poolBullets[rid]
	if B.get("bounces",0) > 0:
		bounce(B, shared_area)
		B["bounces"] = max(0, B["bounces"]-1)
	elif body.is_in_group("Slime"): bounce(B, shared_area)
#		var space:RID = Phys.space_create()
#		var state:PhysicsDirectSpaceState2D = Phys.space_get_direct_state(space)
#		var param:PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
#		param.shape_rid = rid
#		print(state.intersect_ray(B["position"],B["position"]+B["vel"]*_delta))
#		var rest_info:Dictionary = state.get_rest_info(param)
#		print(rest_info)
#
	if body.is_in_group("Player"):
		delete_bullet(rid)
##		$CollisionShape2D.set_deferred("disabled", true)
##		$AnimationPlayer.play("Delete")
	elif B["props"]["death_from_collision"]: delete_bullet(rid)

func bounce(B:Dictionary, shared_area:Area2D):
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


func _get_property_list() -> Array:
	return [{
			name = "sfx_list",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "rand_variation_list",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "Culling",
			type = TYPE_NIL,
			hint_string = "cull_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "cull_bullets",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "cull_except_for",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "cull_margin",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "cull_trigger",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "cull_partial_move",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "cull_minimum_speed_required",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "cull_fixed_screen",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT 
		}]


