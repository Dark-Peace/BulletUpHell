extends Node
class_name customFunctions

###
# here, you can write custom logic to attach to BuHSpawner.gd
# just create a function, and call then call it from BuHSpawner.gd using CUSTOM.<yourfunction>
# it is better than writing custom logic in BuHSpawner.gd
# because your code would be overwritten at each plugin update
###

func bullet_collide_body(body_rid:RID,body:Node,body_shape_index:int,local_shape_index:int,shared_area:Area2D, B:Dictionary, b:RID) -> void:
	pass


func bullet_collide_area(area_rid:RID,area:Area2D,area_shape_index:int,local_shape_index:int,shared_area:Area2D, B:Dictionary, b:RID) -> void:
	pass
