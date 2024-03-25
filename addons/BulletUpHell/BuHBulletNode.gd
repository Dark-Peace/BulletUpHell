extends Area2D

#const FLIP:Array = [-1,1]

@export var ID:String
@export var ignore_children:Array[String] = []

var textures:Array[Dictionary]
#var collisions:Array[Dictionary]
var b:Dictionary

var base_scale



func _draw():
	var texture:Texture2D
	for entry in textures:
		if not entry["enabled"]: continue
#		if not single_texture:
		draw_set_transform_matrix(Transform2D(entry["rotation"]+self.global_rotation, entry["scale"]+self.scale, \
												entry["skew"]+self.skew, self.global_position))
		
#		texture = entry["texture"].get_frame_texture(b["texture"], b["anim_frame"])
		texture = Spawning.get_texture_frame(b, self, entry["texture"])
		if b["props"].has("spec_modulate"):
			Spawning.modulate_bullet(b, texture)
		else: draw_texture(texture, entry["position"], entry["modulate"])
#		draw_texture_rect(texture, Rect2(entry["position"], texture.get_size()), false, entry["modulate"])

func other_area_shape_entered(area_rid:RID, area:Area2D, area_shape_index:int, local_shape_index:int):
	area_shape_entered.emit(area_rid, area, area_shape_index, local_shape_index)
	
func other_body_shape_entered(body_rid:RID, body:Area2D, body_shape_index:int, local_shape_index:int):
	body_shape_entered.emit(body_rid, body, body_shape_index, local_shape_index)

func _ready():
	if ID == "": push_warning("ID missing in node "+String(get_path()))
#	assert(ID != "", "ID missing in node "+String(get_path()))
	name = ID
#	if not get_parent() is InstanceLister:
#		push_warning("Warning: node "+String(get_path())+" must be child of an InstanceLister in order to be accessible for spawning")
	
	for child in get_children():
		if child.name in ignore_children: continue
		
		if child is AnimatedSprite2D:
			var entry:Dictionary
			entry["enabled"] = child.visible
			entry["position"] = child.position + child.offset
			entry["rotation"] = child.rotation
			entry["scale"] = child.scale
			entry["skew"] = child.skew
			entry["texture"] = child.sprite_frames
			if child.flip_h == true or child.flip_v == true:
				push_warning("Use negative scale to flip a BulletNode's sprite, not flip_h or flip_v")
#			entry["flip"] = Vector2(FLIP[int(child.flip_h)],FLIP[int(child.flip_v)])
			entry["modulate"] = child.modulate
			textures.append(entry)
	
#	single_texture = (textures.size() == 1)
#	if single_texture:
#		var entry:Dictionary = textures[0]
#		draw_set_transform_matrix(Transform2D(entry["rotation"], entry["scale"], entry["skew"], entry["position"]))
	
	area_shape_entered.connect(Spawning.bullet_collide_area.bind(self))
	body_shape_entered.connect(Spawning.bullet_collide_body.bind(self))
	
	base_scale = scale
			
#		if child is CollisionShape2D:
#			var entry:Dictionary
#			entry["enabled"] = !child.disabled
#			entry["position"] = child.position + child.offset
#			entry["rotation"] = child.rotation
#			entry["scale"] = child.scale
#			entry["skew"] = child.skew
#			entry["shape"] = child.shape
#			collisions.append(entry)
#
#		if child is CollisionPolygon2D: #TODO
#			var entry:Dictionary
#			entry["enabled"] = !child.disabled
#			entry["position"] = child.position + child.offset
#			entry["rotation"] = child.rotation
#			entry["scale"] = child.scale
#			entry["skew"] = child.skew
#			entry["polygon"] = child.polygon
#			collisions.append(entry)
