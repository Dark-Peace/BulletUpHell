tool
extends NavigationPolygon
class_name PatternLine, "res://addons/BulletUpHell/Sprites/NodeIcons7.png"


var offset = Vector2()
var center = 1
var symmetrical = true


var bullet:String = ""
var nbr:int = 1
var pattern_angle:float = 0
var iterations:int = 1
var forced_angle:float = 0.0
var forced_target:NodePath
var forced_pattern_lookat:bool = true

var other_scene:String
var other_props:Dictionary = {}

var cooldown_spawn:float = 0.017
var cooldown_shoot:float = 0
var cooldown_next_spawn:float = 0
var cooldown_next_shoot:float = 0

enum LATENCE {stay, move, spin, follow, target}
var wait_latence = LATENCE.stay
enum RELEASE {direct, momentum}
var release = RELEASE.direct

var layer_nbr:int = 1
var layer_cooldown_spawn:float = 0
#export (float) var cooldownshoot = 0
var layer_pos_offset:float = 0
var layer_speed_offset:float = 0
var layer_angle_offset:float = 0

var node_target:Node2D


func _get_property_list() -> Array:
	return [
		{
			name = "offset",
			type = TYPE_VECTOR2,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "center",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1, 1000000",
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "symmetrical",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "bullet",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "nbr",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0, 999999",
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "pattern_angle",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-3.1416, 3.1416",
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "iterations",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "Forced Angle",
			type = TYPE_NIL,
			hint_string = "forced_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "forced_angle",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-3.1416, 3.1416",
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "forced_target",
			type = TYPE_NODE_PATH,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "forced_pattern_lookat",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "Non Bullet Spawn",
			type = TYPE_NIL,
			hint_string = "other_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "other_scene",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
			hint_string = "*.tscn",
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "other_props",
			type = TYPE_DICTIONARY,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "Cooldowns",
			type = TYPE_NIL,
			hint_string = "cooldown",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "cooldown_spawn",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "cooldown_shoot",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "cooldown_next_spawn",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "cooldown_next_shoot",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "Wait",
			type = TYPE_NIL,
			hint_string = "wait_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "wait_latence",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = LATENCE,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "wait_release",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = RELEASE,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "Layers",
			type = TYPE_NIL,
			hint_string = "layer_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "layer_nbr",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0, 999999",
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "layer_cooldown_spawn",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "layer_pos_offset",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "layer_speed_offset",
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_DEFAULT 
		},{
			name = "layer_angle_offset",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-3.1416, 3.1416",
			usage = PROPERTY_USAGE_DEFAULT 
		},]

func _init():
	resource_name = "PatternLine"
