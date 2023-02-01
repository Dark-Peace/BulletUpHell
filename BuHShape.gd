tool
extends AnimatedSprite

var ID:String
var simple_collision:Shape2D
var simple_texture:Texture
# TODO frames

var col_spawn:Shape2D
var col_wait:Shape2D
var col_shoot:Shape2D
var col_moving:Shape2D
var col_delete:Shape2D


func _ready() -> void:
	if not Engine.is_editor_hint():
		var dict:Dictionary = {}
		var P
		for p in get_property_list():
			P = p["name"]
			if (not P in ["frames","simple_collision","simple_texture","col_spawn","col_wait","col_shoot","col_moving","col_delete"] \
				or get(P) == null) or (P in ["flip_h","flip_v"] and get(P) == false): continue
			
			dict[P] = props.get(P)
		
		Spawning.new_bullet(ID, dict)
		queue_free()
	else:
		if not props: props = BulletProps.new()


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
