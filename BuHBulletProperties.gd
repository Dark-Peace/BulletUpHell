tool
extends Path2D

export (String) var id = ""
export (PackedDataContainer) var props


func _ready():
	randomize()
	add_to_group("BulletProps")
	if not Engine.is_editor_hint():
		if props.homing_target: props.node_homing = get_node(props.homing_target)
		elif props.homing_special_target: props.node_homing = Spawning.get_special_target(props.homing_special_target)
		elif not (props.homing_list.size() < 2 or props.homing_list_ordered): props.homing_list.shuffle()
		if props.get("a_curve_movement") > 0:
			assert(curve.get_point_count() > 0, \
				"BulletProperties has no curve. Draw one like you'd draw a Path2D with the BulletPattern node")
			props.curve = curve
		
		var dict:Dictionary = {}; var P; var has_random:bool=false;
		var allow_random:bool = rand_range(0,1) <= props["r_randomisation_chances"];
		for p in props.get_property_list():
			P = p["name"]
			if P in ["__data__","spec_top_level","spec_ally","a_angular_equation","mask","r_randomisation_chances",
				"Reference","Resource","resource_local_to_scene","resource_path","Resource","node_container",
				"resource_name","PackedDataContainer","script","Script Variables","homing_position", "homing_list_ordered",
				"Advanced Movement","Advanced Scale","Animations","Homing","Special Properties","Triggers"]:
					continue
			elif P in ["a_direction_equation","trigger_container", "anim_spawn_texture","anim_waiting_texture",\
				"anim_delete_texture","anim_spawn_collision","anim_waiting_collision","anim_delete_collision",\
				"homing_special_target","homing_group"] and props.get(P) == "": continue
			elif P in ["a_speed_multi_iterations","scale_multi_iterations","spec_bounces","spec_rotating_speed", \
				"spec_warn","spec_explo","spec_modulate_loop","beam_length_per_ray","spec_trail_length"] \
				and int(props.get(P)) == int(0): continue
			elif P in ["anim_idle_sfx","anim_spawn_sfx","anim_waiting_sfx","anim_delete_sfx"] and props.get(P) == -1: continue
			elif P in ["spec_tourment","spec_no_collision"] and props.get(P) == false: continue
			elif P == "homing_target" and props.get(P) == NodePath(): continue
			elif P == "homing_position" and props.get(P) == Vector2(): continue
			elif P in ["spec_modulate","curve"] and props.get(P) == null: continue
			elif P in ["homing_list","homing_surface"] and props.get(P).empty(): continue
			
			elif P in ["homing_steer","homing_time_start","homing_duration","node_homing"] \
				and not ((dict.get("homing_target",false) or dict.get("homing_position",false)) \
				or (dict.get("homing_group",false) or dict.get("homing_special_target",false)) \
				or (dict.get("homing_surface",false) or dict.get("homing_list",false))): continue
			elif P in ["a_speed_multiplier","a_speed_multi_scale"] \
				and not dict.get("a_speed_multi_iterations",false): continue
			elif P in ["scale_multiplier","scale_multi_scale"] \
				and not dict.get("scale_multi_iterations",false): continue
			elif P in ["beam_width","beam_bounce_amount"] \
				and not dict.get("beam_length_per_ray",false): continue
			elif P == "trigger_wait_for_shot" and not dict.get("trigger_container",false): continue
			elif P == "homing_select_in_group" and not dict.get("homing_group",false): continue
			elif P in ["homing_when_list_ends"] and not dict.get("homing_list",false): continue
			elif P in ["spec_trail_modulate","spec_trail_width"] and not dict.get("spec_trail_length",false): continue
			
			elif P.left(2) == "r_":
				if not allow_random or \
				(p["type"] == TYPE_STRING and props.get(P) == "") or \
				(p["type"] == TYPE_VECTOR3 and props.get(P) == Vector3()) or \
				(p["type"] == TYPE_REAL and props.get(P) == 0.0) or \
				(p["type"] == TYPE_ARRAY and props.get(P).empty()): continue
				
				if p["type"] == TYPE_STRING: props.set(P, Array(props.get(P).split(";",false)))
				
				if not has_random:
					has_random = true
					dict["has_random"] = true
					
			if "anim_" in P and ";" in props.get(P):
				props.set(P, Array(props.get(P).split(";",false)))
			dict[P] = props.get(P)
		Spawning.new_bullet(id, dict)
		queue_free()
	elif not props: props = BulletProps.new()
