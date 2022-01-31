tool
extends Node

export (String) var id = ""
export (PackedDataContainer) var props


func _ready():
	add_to_group("BulletProps")
	if not Engine.is_editor_hint():
		if props.homing_target: props.node_homing = get_node(props.homing_target)
		Spawning.new_bullet(id, props)
		queue_free()
	else:
		if not props: props = BulletProps.new()
