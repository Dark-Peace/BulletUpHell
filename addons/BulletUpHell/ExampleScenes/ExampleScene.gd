extends Node2D



func _process(delta):
	$FPS.text = str(Engine.get_frames_per_second())+" FPS\n"+str(Spawning.poolBullets.size())



func _on_PlayerTest_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
#	print("ok")
	pass

