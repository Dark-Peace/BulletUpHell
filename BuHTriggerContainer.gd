tool
extends Node

export (String) var id
export (String, MULTILINE) var advanced_controls = ""
export (Array, RichTextEffect) var triggers = [null]
export (Array, NavigationPolygon) var patterns = [null]

var commands:Array = []


func _ready():
	if not Engine.is_editor_hint() and triggers != [null] and patterns != [null]:
		for i in triggers:
			if i.resource_name == "TrigCol" and i.target_to_collide:
				i.node_collide = get_node(i.target_to_collide)
			elif i.resource_name == "TrigPos" and i.target:
				i.node_target = get_node(i.target)
			Spawning.new_trigger(id+"/"+String(triggers.find(i)), i)
		for j in patterns.size(): Spawning.new_pattern(id+"/"+String(j), patterns[j])
		Spawning.new_container(self)
		
		if advanced_controls != "":
			commands = advanced_controls.split("\n", false)
			for line in commands.size(): if "=" in commands[line]:
				commands[line] = commands[line].split("=",false)


func define_trigger(res:Array, t:String, node:Node2D):
	var curr_t = Spawning.trigger(id+"/"+t)
	if not res.has(curr_t.resource_name): res.append(curr_t.resource_name)
	if curr_t.resource_name == "TrigTime":
		get_tree().create_timer(curr_t.time).connect("timeout", node,"trig_timeout")


func getCurrentTriggers(node:Node2D):
	if node.trigger_counter < 0: return
	var res:Array = []
	var list = commands[node.trigger_counter][0]
	if "/" in list:
		list = list.split("/")
		for sublist in list:
			if "+" in list:
				sublist = sublist.split("+")
				for t in sublist: define_trigger(res, t, node)
			else: define_trigger(res, sublist, node)
	elif "+" in list:
		list = list.split("+")
		for t in list: define_trigger(res, t, node)
	else: define_trigger(res, list, node)
	return res


func resetTriggers(node:Node2D):
	node.trig_signal = ""
	node.trig_timeout = false
	node.trig_collider = null


func checkTriggers(node:Node2D):
	if node.trigger_counter < 0:
		return
	var ok = false
	var cond_index:int = 0
	var list = commands[node.trigger_counter][0]
	if "/" in list:
		list = list.split("/")
		for sublist in list:
			var or_ok = true
			if "+" in sublist:
				ok = true
				sublist = sublist.split("+")
				for t in sublist: if not checkTrigger(node, t):
					or_ok = false
					break
			else: or_ok = checkTrigger(node, sublist)
			if not or_ok: cond_index += 1
			else:
				ok=true
				break
	elif "+" in list:
		ok = true
		list = list.split("+")
		for t in list: if not checkTrigger(node, t):
			ok=false
			break
	else: ok = checkTrigger(node, list)
	
	if ok:
		list = commands[node.trigger_counter][1]
		if "/" in list:
			list = list.split("/")
			if "+" in list:
				list = list.split("+")
				for p in list: Spawning.spawn(node, id+"/"+p)
			else: Spawning.spawn(node, id+"/"+list[cond_index])
		elif "+" in list:
			list = list.split("+")
			for p in list: Spawning.spawn(node, id+"/"+p)
		else: Spawning.spawn(node, id+"/"+list)
		
		if node.trigger_counter+1 < commands.size():
			list = commands[node.trigger_counter+1].split(">")
			if list[0]:
				if not node.trig_iter.has(node.trigger_counter+1):
					node.trig_iter[node.trigger_counter+1] = int(list[0])-1
				else: node.trig_iter[node.trigger_counter+1] -= 1
				
				if node.trig_iter[node.trigger_counter+1] > 0: node.trigger_counter = int(list[1])
				else: node.trigger_counter += 2
			elif list[1]:
				if list[1] == "q": node.call_deferred("queue_free")
				elif list[1] == "|": node.trigger_counter = -1
				else: node.trigger_counter = int(list[1])
			else: node.trigger_counter += 2
			if node.trigger_counter >= commands.size(): node.trigger_counter = -1
			
			resetTriggers(node)
			getCurrentTriggers(node)
		else: return true

func checkTrigger(node:Node2D, t_id:String):
	var t = Spawning.trigger(id+"/"+t_id)
	
	match t.resource_name:
		"TrigCol":
			if t.group_to_collide != "" and t.group_to_collide in node.trig_collider.get_groups(): return true;
			elif t.node_collide == node.trig_collider: return true
			else: return (t.on_bounce and node.bounces > 0)
		"TrigTime":
			if node.trig_timeout: return true
		"TrigPos":
			var arg = node.global_position
			if t.node_target: return arg.distance_to(t.node_target.global_position) < t.distance
			match t.on_axis:
				t.AXIS.X: return abs(arg.x-t.pos.x) < t.distance
				t.AXIS.Y: return abs(arg.y-t.pos.y) < t.distance
				t.AXIS.BOTH: return arg.distance_to(t.pos) < t.distance
		"TrigSig": return node.trig_signal == t.sig







