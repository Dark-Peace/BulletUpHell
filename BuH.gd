tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("SpawnerGlobal", "AnimationPlayer", preload("res://addons/BulletUpHell/BuHSpawner.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons4.png"))
	add_custom_type("SpawnPattern", "Path2D", preload("res://addons/BulletUpHell/BuHPattern.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons1.png"))
	add_custom_type("BulletPattern", "Node", preload("res://addons/BulletUpHell/BuHBulletProperties.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons2.png"))
	add_custom_type("TriggerContainer", "Node", preload("res://addons/BulletUpHell/BuHTriggerContainer.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons3.png"))
	add_custom_type("SpawnPoint", "Node2D", preload("res://addons/BulletUpHell/BuHSpawnPoint.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons14.png"))
	pass
 
func _exit_tree():
	remove_custom_type("SpawnPoint")
	remove_custom_type("SpawnPattern")
	remove_custom_type("BulletPattern")
	remove_custom_type("TriggerContainer")
	remove_custom_type("SpawnerGlobal")
	pass
