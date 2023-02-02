@tool
@icon("res://addons/BulletUpHell/Sprites/NodeIcons15.png")
extends PackedDataContainer
class_name BulletProps

#enum SHAPE {standart=1, arrow=0, knife=2, marakas=21, tear=20, mask=-1, anger_shot=-2, explo_standart=4}
#enum EMO {NO, joy, anxiety, cold_anger
#		anger, sadness, fear, shame, envy, veangeance, megalomania, hate,
#		pride, psychopathy, sadism, machiavelism,
#		empath_like, dream_like, self_like,
#		doubt, love, obsession, special_effect}


var speed:float = 100
var scale = 1
var angle = 0
var groups = []
var death_after_time:float = 30
var death_outside_box:Rect2 = Rect2()
var death_from_collision:bool = true

## animations
var anim_idle_texture:String = "0"
var anim_spawn_texture:String
var anim_waiting_texture:String
var anim_delete_texture:String
var anim_idle_collision:String = "0"
var anim_spawn_collision:String
var anim_waiting_collision:String
var anim_delete_collision:String
var anim_idle_sfx:int = -1 #TODO change to string
var anim_spawn_sfx:int = -1
var anim_waiting_sfx:int = -1
var anim_delete_sfx:int = -1

## movement
enum CURVE_TYPE{None,LoopFromStart,OnceThenDie,OnceThenStay,LoopFromEnd}
var a_direction_equation = ""
var a_angular_equation = ""
var a_curve_movement:int = CURVE_TYPE.None
var curve:Curve2D = null
var a_speed_multiplier:Curve = Curve.new()
var a_speed_multi_iterations = 0
var a_speed_multi_scale:float

## special props
var spec_bounces = 0
var spec_no_collision = false
var spec_modulate:Gradient
var spec_modulate_loop:float = 0.0
var spec_rotating_speed = 0.0
var spec_trail_length:float = 0.0
var spec_trail_width:float = 0.0
var spec_trail_modulate:Color = Color.WHITE

## triggers
var trigger_container:String
var trigger_wait_for_shot = true

## homing
enum GROUP_SELECT{Nearest_on_homing,Nearest_on_spawn,Nearest_on_shoot,Nearest_anywhen,Random}
enum LIST_BEHAVIOUR{Stop, Loop, Reverse}
enum TARGET_TYPE{Nodepath, Position, SpecialNode, Group, Surface, List}
var homing_type:int = TARGET_TYPE.Nodepath : set = set_homing_type
var homing_target:NodePath = NodePath()
var homing_special_target:String
var homing_group:String
var homing_select_in_group:int = GROUP_SELECT.Nearest_on_homing
var homing_surface:Array
var homing_list:Array
var homing_list_ordered:bool = true
var homing_when_list_ends:int = LIST_BEHAVIOUR.Stop
var homing_position:Vector2
var homing_steer = 0
var homing_time_start = 0
var homing_duration = 999

## laser beams
var beam_length_per_ray:float = 0
var beam_width:float = 0
var beam_bounce_amount:int = 0

## advanced scale
var scale_multi_iterations = 0
var scale_multiplier:Curve = Curve.new()
var scale_multi_scale = 1

## random
var r_randomisation_chances:float=1
# physics
var r_speed_multi_iter_variation:Vector3
var r_speed_multi_scale_variation:Vector3
var r_rotating_variation:Vector3
var r_steer_variation:Vector3
var r_homing_delay_variation:Vector3
var r_homing_dur_variation:Vector3
var r_scale_multi_iter_variation:Vector3
var r_scale_multi_scale_variation:Vector3
var r_trail_length_variation:Vector3
var r_trail_color_variation:Vector3
# setup
var r_speed_choice:String
var r_speed_variation:Vector3
var r_scale_variation:Vector3
var r_angle_variation:Vector3
var r_group_choice:Array
var r_scale_choice:String
var r_angle_choice:String
var r_dir_equation_choice:String
var r_curve_choice:Array
var r_speed_multi_curve_choice:Array
var r_homing_target_choice:Array
var r_special_target_choice:String
var r_group_target_choice:String
var r_pos_target_choice:String
var r_steer_choice:String
var r_homing_delay_choice:String
var r_homing_dur_choice:String
var r_scale_multi_curve_choice:Array
var r_bounce_choice:String
var r_death_after_choice:String
var r_death_after_variation:Vector3
var r_trigger_choice:String
var r_bounce_variation:Vector3
var r_death_outside_chances:float
var r_wait_for_shot_chances:float
# draw
# animations directly in
#todo
var r_beam_length_choice:String
var r_beam_length_variation:Vector3
var r_beam_bounce_choice:String
var r_beam_width_variation:Vector3
var r_no_coll_chances:float
var r_modulate_variation:Vector3


var node_homing:Node2D
var node_container:Node2D


enum RANDTYPE{List, Variation}

func set_homing_type(value):
	homing_type = value
	_get_property_list()
	notify_property_list_changed()

func _get_property_list() -> Array:
	var PL1 = [{
			name = "speed",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "scale",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "angle",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "-3.1416, 3.1416",
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "groups",
			type = TYPE_PACKED_STRING_ARRAY,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Animations",
			type = TYPE_NIL,
			hint_string = "anim_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "anim_idle_texture",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_spawn_texture",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_waiting_texture",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_delete_texture",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_idle_collision",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_spawn_collision",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_waiting_collision",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_delete_collision",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_idle_sfx",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_spawn_sfx",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_waiting_sfx",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "anim_delete_sfx",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Special Properties",
			type = TYPE_NIL,
			hint_string = "spec_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "spec_bounces",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_no_collision",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_modulate",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "Gradient",
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_modulate_loop",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_trail_length",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_trail_width",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_trail_modulate",
			type = TYPE_COLOR,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "spec_rotating_speed",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Destruction",
			type = TYPE_NIL,
			hint_string = "death_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "death_after_time",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "death_outside_box",
			type = TYPE_RECT2,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "death_from_collision",
			type = TYPE_BOOL,
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
			name = "a_curve_movement",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = CURVE_TYPE,
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
			type = TYPE_FLOAT,
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
			name = "homing_type",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = TARGET_TYPE,
			usage = PROPERTY_USAGE_DEFAULT
		}]
	var PL_homing = [{
			name = "homing_target",
			type = TYPE_NODE_PATH,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_position",
			type = TYPE_VECTOR2,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_special_target",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_group",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_surface",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_list",
			type = TYPE_ARRAY,
			usage = PROPERTY_USAGE_DEFAULT
		}]
	var PL_homing_group = [{
			name = "homing_select_in_group",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = GROUP_SELECT,
			usage = PROPERTY_USAGE_DEFAULT
		}]
	var PL_homing_list = [{
			name = "homing_list_ordered",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_when_list_ends",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = LIST_BEHAVIOUR,
			usage = PROPERTY_USAGE_DEFAULT
		}]
	
	PL_homing = [PL_homing[homing_type]]
	if homing_type in [TARGET_TYPE.Group, TARGET_TYPE.Surface]: PL_homing += PL_homing_group
	elif homing_type == TARGET_TYPE.List: PL_homing += PL_homing_list
	
	var PL2 = [{
			name = "homing_steer",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_time_start",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "homing_duration",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Laser Beam",
			type = TYPE_NIL,
			hint_string = "beam_",
			usage = PROPERTY_USAGE_GROUP
		},{
			name = "beam_length_per_ray",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "beam_width",
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "beam_bounce_amount",
			type = TYPE_INT,
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
			type = TYPE_FLOAT,
			usage = PROPERTY_USAGE_DEFAULT
		},{
			name = "Random",
			type = TYPE_NIL,
			hint_string = "r_",
			usage = PROPERTY_USAGE_GROUP
		},
		{ name = "r_randomisation_chances", type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE, hint_string = "0, 1", usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_speed_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_speed_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_scale_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_scale_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_angle_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_angle_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_group_choice", type = TYPE_ARRAY, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_bounce_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_bounce_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_no_coll_chances", type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE, hint_string = "0, 1", usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_modulate_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_trail_length_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_trail_color_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_rotating_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_death_after_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_death_after_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_death_outside_chances", type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE, hint_string = "0, 1", usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_dir_equation_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_curve_choice", type = TYPE_ARRAY, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_speed_multi_curve_choice", type = TYPE_ARRAY, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_speed_multi_iter_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_speed_multi_scale_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_trigger_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_wait_for_shot_chances", type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE, hint_string = "0, 1", usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_homing_target_choice", type = TYPE_ARRAY, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_special_target_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_group_target_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_pos_target_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_steer_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_steer_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_homing_delay_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_homing_delay_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_homing_dur_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_homing_dur_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_beam_length_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_beam_length_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_beam_bounce_choice", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_beam_width_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_scale_multi_curve_choice", type = TYPE_ARRAY, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_scale_multi_iter_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT },
		{ name = "r_scale_multi_scale_variation", type = TYPE_VECTOR3, usage = PROPERTY_USAGE_DEFAULT }
		]
#	if not r_random_array.is_empty():
#		for p in r_random_array.keys():
#			PL.append({name=p,type=typeof(r_random_array[p]),usage=PROPERTY_USAGE_DEFAULT})
#	notify_property_list_changed()
	return PL1+PL_homing+PL2

#func _set(p:String, value) -> bool:
#	if p == "r_create_new":
#		speed += 10
#		match r_random_change:
#			RANDTYPE.List: r_random_array["r_"+r_property_name] = []
#			RANDTYPE.Variation: r_random_array["r_"+r_property_name] = int(3)
##	if p in r_random_array:
##		r_random_array[p] = value
#	notify_property_list_changed()
#	return p in self
