tool
extends Node2D


var auto_pattern_id:String = ""
var auto_start_on_cam:bool = true
var auto_start_after_time:float = 0.0
var auto_start_at_distance:float = 5
var auto_distance_from:NodePath
var trigger_container:NodePath

var trig_container
var trigger_counter = 0
var trig_timeout = false
var trig_collider
var trig_signal

var rotating_speed = 0.0
var active = true 

var auto_call = false

func _ready():
	if not Engine.is_editor_hint():
		if trigger_container:
			trig_container = get_node(trigger_container)
			set_process(false)
		
		if auto_start_on_cam:
			assert(auto_pattern_id != "")
			var instance = VisibilityNotifier2D.new()
			instance.connect("screen_entered", self, "on_screen", [true])
			instance.connect("screen_exited", self, "on_screen", [false])
		elif auto_distance_from: set_process(true)
		elif auto_pattern_id:
			if auto_start_after_time > float(0.0):
				yield(get_tree().create_timer(auto_start_after_time), "timeout")
			auto_call = true
			set_process(active)
	
	if active and auto_pattern_id:
		if auto_start_after_time > float(0.0):
			yield(get_tree().create_timer(auto_start_after_time), "timeout")
		auto_call = true
		set_process(active)

func _process(delta):
	if not Engine.is_editor_hint():
		if auto_distance_from and global_position.distance_to(get_node(auto_distance_from).global_position) <= auto_start_at_distance:
			active = true
		checkTrigger()
		
		if auto_call and active and auto_pattern_id:
			set_process(false)
			Spawning.spawn(self, auto_pattern_id)


func on_screen(is_on):
	if is_on and auto_start_after_time > float(0.0):
		yield(get_tree().create_timer(auto_start_after_time), "timeout")
	active = is_on
	set_process(active)

func triggerSignal(sig):
	trig_signal = sig
	checkTrigger()

func trig_timeout():
	trig_timeout = true
	checkTrigger()

func checkTrigger():
	if trig_container: trig_container.checkTriggers(self)
	
func _get_property_list() -> Array:
	return [
		{
			name = "active",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "rotating_speed",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "Autostart & Triggering",
			type = TYPE_NIL,
			hint_string = "auto_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "auto_pattern_id",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "auto_start_on_cam",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "auto_start_after_time",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "auto_start_at_distance",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "auto_distance_from",
			type = TYPE_NODE_PATH,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "Advanced Triggering",
			type = TYPE_NIL,
			hint_string = "trigger_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "trigger_id",
			type = TYPE_NODE_PATH,
			usage = PROPERTY_USAGE_DEFAULT 
		}]
