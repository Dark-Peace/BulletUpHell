@tool
extends Node
class_name TriggerContainer

@export var id:String
@export_multiline var advanced_controls:String = ""
@export var triggers:Array[RichTextEffect] = [null]
@export var patterns:Array[Pattern] = [null]
@export var pool_amount:int = 50

var commands:Array = []


func _ready():
	if not (not Engine.is_editor_hint() and triggers != [null]): return# and patterns != [null]): return
	for i in triggers:
		if i.resource_name == "TrigCol" and i.target_to_collide:
			i.node_collide = get_node(i.target_to_collide)
		elif i.resource_name == "TrigPos" and i.target:
			i.node_target = get_node(i.target)
		Spawning.new_trigger(id+"/"+str(triggers.find(i)), i)
	for j in patterns.size(): Spawning.new_pattern(id+"/"+str(j), patterns[j])
	Spawning.new_container(self)
	
	if advanced_controls != "":
		commands = advanced_controls.split("\n", false)
		for line in commands.size():
			if "=" in commands[line]:
				commands[line] = commands[line].split("=",false)

func create_pool(shared_area_name:String, pool_amount:int):
	if pool_amount <= 0: return
	for p in patterns:
		var props = Spawning.pattern(p.bullet)["bullet"]
		Spawning.create_pool(props, shared_area_name, pool_amount, !Spawning.bullet(props).has("anim_idle_collision"))

func define_trigger(res:Array, t:String, b, rid):
	var curr_t = Spawning.trigger(id+"/"+t)
	if not res.has(curr_t.resource_name): res.append(curr_t.resource_name)
	if curr_t.resource_name == "TrigTime":
		get_tree().create_timer(curr_t.time).connect("timeout",Callable(Spawning,"trig_timeout").bind(b, rid))


func getCurrentTriggers(b, rid):
	if b.get("trigger_counter") < 0: return
	var res:Array = []
	var list = commands[b.get("trigger_counter")][0]
	if "/" in list:
		list = list.split("/")
		for sublist in list:
			if "+" in list:
				sublist = sublist.split("+")
				for t in sublist: define_trigger(res, t, b, rid)
			else: define_trigger(res, sublist, b, rid)
	elif "+" in list:
		list = list.split("+")
		for t in list: define_trigger(res, t, b, rid)
	else: define_trigger(res, list, b, rid)
	return res


func resetTriggers(b, isNode:bool):
	if isNode:
		b.trig_signal = ""
		b.trigger_timeout = false
		b.trig_collider = null
	else:
		b.trig_signal = ""
		b.trig_timeout = false
		b.trig_collider = null

func callAction(isNode:bool, b, pattern:String):
	if isNode: b.callAction()
	else: Spawning.spawn(b, pattern, b.get("shared_area").name)

func applyTrigger(b, list, counter:int, cond_index:int, isNode:bool):
	list = commands[counter][1]
	if "/" in list:
		list = list.split("/")
		if "+" in list:
			list = list.split("+")
			for p in list: callAction(isNode, b, id+"/"+p)
		else: callAction(isNode, b, id+"/"+list)
	elif "+" in list:
		list = list.split("+")
		for p in list: callAction(isNode, b, id+"/"+p)
	else: callAction(isNode, b, id+"/"+list)

func isTriggerChecked(list, b, isNode:bool) -> Array:
	var ok:bool = false
	var cond_index:int = 0
	if "/" in list:
		list = list.split("/")
		for sublist in list:
			var or_ok = true
			if "+" in sublist:
				ok = true
				sublist = sublist.split("+")
				for t in sublist: if not checkTrigger(b, t, isNode):
					or_ok = false
					break
			else: or_ok = checkTrigger(b, sublist, isNode)
			if not or_ok: cond_index += 1
			else:
				ok = true
				break
	elif "+" in list:
		ok = true
		list = list.split("+")
		for t in list: if not checkTrigger(b, t, isNode):
			ok = false
			break
	else: ok = checkTrigger(b, list, isNode)
	return [ok, cond_index]

func checkTriggers(b, rid):
	if b["trigger_counter"] < 0: return false
	var trigger_counter:int
	if b is Dictionary: trigger_counter = b["trigger_counter"]
	elif b is Node: trigger_counter = b.trigger_counter
	
	var list = commands[trigger_counter][0]
	var isNode:bool = (b is Node)
	var trigger_result:Array = isTriggerChecked(list, b, isNode)
	if trigger_result[0]:
		applyTrigger(b, list, trigger_counter, trigger_result[1], isNode)
	
		if trigger_counter+1 < commands.size():
			updateBase(b, list, trigger_counter, rid, isNode)
		else: return true

func updateBase(b, list, trigger_counter:int, rid, isNode:bool):
	list = commands[trigger_counter+1].split(">")
	if list[0]:
		if not b.get("trig_iter").has(trigger_counter+1):
			b.get("trig_iter")[trigger_counter+1] = int(list[0])-1
		else: b.get("trig_iter")[trigger_counter+1] -= 1
		
		if b.get("trig_iter")[trigger_counter+1] > 0: setTriggerCounter(isNode, b, int(list[1]))
		else: incTriggerCounter(isNode, b, 2)
	elif list[1]:
		if list[1] == "q":
			if not isNode: Spawning.delete_bullet(rid)
			else: rid.queue_free()
		elif list[1] == "|": incTriggerCounter(isNode, b, -1)
		else: setTriggerCounter(isNode, b, int(list[1])) #b["trigger_counter"] = int(list[1])
	else: incTriggerCounter(isNode, b, 2)
	if trigger_counter >= commands.size(): incTriggerCounter(isNode, b, -1)
	
	resetTriggers(b, isNode)
	getCurrentTriggers(b, rid)

func setTriggerCounter(node:bool, b, value:int):
	if node: b.trigger_counter = value
	else: b["trigger_counter"] = value

func incTriggerCounter(node:bool, b, value:int):
	if node: b.trigger_counter += value
	else: b["trigger_counter"] += value

func checkTrigger(b, t_id:String, isNode:bool):
	var t = Spawning.trigger(id+"/"+t_id)
	
	match t.resource_name:
		"TrigCol":
			if t.group_to_collide != "": return (t.group_to_collide in b.get("trig_collider").get_groups())
			elif t.node_collide: return t.node_collide == b.get("trig_collider")
			elif t.on_bounce: return (b.get("bounces", 0) > 0)
			else: return true
		"TrigTime":
			if isNode: return b.trig_timeout(t.time)
			elif b.get("trig_timeout"): return true
		"TrigPos":
			var arg = b.get("position")
			if t.node_target: return arg.distance_to(t.node_target.global_position) < t.distance
			match t.on_axis:
				t.AXIS.X: return abs(arg.x-t.pos.x) < t.distance
				t.AXIS.Y: return abs(arg.y-t.pos.y) < t.distance
				t.AXIS.BOTH: return arg.distance_to(t.pos) < t.distance
		"TrigSig": return b.get("trig_signal") == t.sig
	
	return false
