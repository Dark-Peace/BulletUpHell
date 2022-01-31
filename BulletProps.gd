tool
extends PackedDataContainer
class_name BulletProps, "res://addons/BulletUpHell/Sprites/NodeIcons15.png"

enum SHAPE {standart=1, arrow=0, knife=2, marakas=21, tear=20, mask=-1, anger_shot=-2, explo_standart=4}
enum EMO {NO, joy, anxiety, cold_anger
		anger, sadness, fear, shame, envy, veangeance, megalomania, hate,
		pride, psychopathy, sadism, machiavelism,
		empath_like, dream_like, self_like,
		doubt, love, obsession, special_effect}


var speed:float = 100
var shape = SHAPE.standart
var scale = 1
var mask = EMO.NO
var angle = 0

## movement
var a_direction_equation = ""
var a_angular_equation = ""
var a_speed_multiplier:Curve = Curve.new()
var a_speed_multi_iterations = 0
var a_speed_multi_scale:float

#export (Dictionary) var speed_multiplier = {"type": 0, "multiplier": Resource, "speed": 1}

## special props
var spec_top_level = true
var spec_tourment = false
var spec_explo = 0
var spec_warn = 0.0 #todo
var spec_ally = false
var spec_bounces = 0
var spec_states = {"Fire": 0, "Frozen": 0, "Glue": 0}
var spec_no_collision = false
var spec_rotating_speed = 0.0

## triggers
var trigger_container:String
var trigger_wait_for_shot = true

## homing
var homing_target
var homing_position
var homing_steer = 0
var homing_time_start = 0
var homing_duration = 999

## advanced scale
var scale_multi_iterations = 0
var scale_multiplier:Curve = Curve.new()
var scale_multi_scale = 1


var node_homing:Node2D
var node_container:Node2D



func _get_property_list() -> Array:
	return [{
			name = "speed",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "shape",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = SHAPE,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "scale",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "angle",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-3.1416, 3.1416",
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "mask",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = EMO,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Special Properties",
			type = TYPE_NIL,
			hint_string = "spec_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "spec_top_level",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_tourment",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_explo",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_warn",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_ally",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_bounces",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_states",
			type = TYPE_DICTIONARY,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_no_collision",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_rotating_speed",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Advanced Movement",
			type = TYPE_NIL,
			hint_string = "a_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "a_direction_equation",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "a_angular_equation",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "a_speed_multiplier",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "Curve",
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "a_speed_multi_iterations",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-1, 999999",
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "a_speed_multi_scale",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Triggers",
			type = TYPE_NIL,
			hint_string = "trigger_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "trigger_container",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "trigger_wait_for_shot",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Homing",
			type = TYPE_NIL,
			hint_string = "homing_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "homing_target",
			type = TYPE_NODE_PATH,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_position",
			type = TYPE_VECTOR2,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_steer",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_time_start",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_duration",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Advanced Scale",
			type = TYPE_NIL,
			hint_string = "scale_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "scale_multi_iterations",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-1, 999999",
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "scale_multiplier",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "Curve",
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "scale_multi_scale",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT
		}]













