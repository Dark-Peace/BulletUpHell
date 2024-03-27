@tool
@icon("res://addons/BulletUpHell/Sprites/NodeIcons4.png")
extends NavigationPolygon
class_name Pattern

@export var bullet:String = ""
@export var nbr:int = 1
@export var iterations:int = 1
@export var follows_parent:bool = false

@export_group("Forced Spawning Angle", "pattern_")
@export var pattern_angle:float = 0
@export var pattern_angle_target:NodePath
@export var pattern_angle_mouse:bool = false
@export_group("Forced Shooting Angle", "forced_")
@export var forced_angle:float = 0.0
@export var forced_target:NodePath
@export var forced_lookat_mouse:bool = false
@export var forced_pattern_lookat:bool = true

@export_group("Cooldowns", "cooldown_")
@export var cooldown_stasis:bool = false
@export var cooldown_spawn:float = 0.017
@export var cooldown_shoot:float = 0
@export var cooldown_next_spawn:float = 0
@export var cooldown_next_shoot:float = 0

@export_group("Wait", "wait_")
enum LATENCE {stay, move, spin, follow, target}
@export var wait_latence = LATENCE.stay
enum MOMENTUM{None, TRANS_LINEAR,TRANS_SINE,TRANS_QUINT,TRANS_QUART,TRANS_QUAD,TRANS_EXPO,TRANS_ELASTIC,TRANS_CUBIC, \
				TRANS_CIRC,TRANS_BOUNCE,TRANS_BACK}
@export var wait_tween_momentum:MOMENTUM = MOMENTUM.None
@export var wait_tween_length:float = 0
@export var wait_tween_time:float = 0

var has_random
var node_target:Node2D

