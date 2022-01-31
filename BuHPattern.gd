tool
extends Path2D

export (String) var id = ""
export (NavigationPolygon) var pattern
export (bool) var preview_spawn = false
export (bool) var preview_shoot = false setget set_pre_shoot

var preview_bullet:BulletProps


func _ready():
	if not Engine.is_editor_hint() and pattern:
		if pattern.forced_target: pattern.node_target = get_node(pattern.forced_target)
		if pattern.resource_name == "PatternCustomShape":
			print(curve.get_baked_length())
			pattern.shape = curve
			var follow = PathFollow2D.new()
			add_child(follow)
			var length = curve.get_baked_length()
			for b in pattern.nbr:
				var pos_on_curve
				if pattern.closed_shape: pos_on_curve = length/pattern.nbr*b
				else: pos_on_curve = length/(pattern.nbr-1)*b
				follow.offset = pos_on_curve
				pattern.angles.append(follow.rotation-PI/2)
			remove_child(follow)
		Spawning.new_pattern(id, pattern)
		queue_free()

func _process(delta):
	if preview_spawn and Engine.is_editor_hint():
		update()
			
 
func set_pre_shoot(value):
	preview_shoot = value

func _draw():
	if not preview_spawn: return
	if not pattern.resource_name == "PatternCustomShape": return
	var length = curve.get_baked_length()
	var follow
	if preview_shoot:
		follow = PathFollow2D.new()
		add_child(follow)
	
	for b in pattern.nbr:
		var pos_on_curve
		if pattern.closed_shape: pos_on_curve = length/pattern.nbr*b
		else: pos_on_curve = length/(pattern.nbr-1)*b
		var pos = curve.interpolate_baked(pos_on_curve)
		draw_circle(pos, 10, Color.red)
		
		if preview_shoot:
			follow.offset = pos_on_curve
			draw_line(pos, pos+Vector2(32,0).rotated(follow.rotation-PI/2),Color.yellow,3)
#			var points = curve.get_baked_points()
#			for p in points.size():
#				points.set(p, points[p])
#			draw_polyline(points, Color.red, 2.0)
	if preview_shoot:
		remove_child(follow)





