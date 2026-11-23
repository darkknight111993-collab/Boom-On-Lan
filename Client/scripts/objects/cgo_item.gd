class_name CGOItem
extends "res://scripts/objects/c_game_object.gd"

## CGOItem - Collectible item dropped on map
## Ported from CA.exe CGOItem (sub_457DA7) with floating bobbing & shadow

signal collected(item: CGOItem, player: Node2D)
signal incinerated(item: CGOItem)

@export var item_code: String = "Item/Bomb"

var shadow_node: Sprite2D
var bob_time: float = 0.0

func setup(col: int, row: int, code: String) -> void:
	set_cell(col, row)
	item_code = code

func _ready() -> void:
	# Add shadow beneath item
	shadow_node = Sprite2D.new()
	shadow_node.centered = false
	var sdb: Object = _get_sprite_db()
	if sdb:
		var sh_data: Dictionary = sdb.get_frame("Shadow/Shadow", 0)
		if not sh_data.is_empty() and sh_data.get("texture"):
			shadow_node.texture = sh_data.texture
			shadow_node.position = -sh_data.offset
	add_child(shadow_node)
	
	# Main item sprite
	super._ready()
	play_anim(item_code, [[0, -1]], false)

func _on_update(delta: float) -> void:
	# Floating bobbing motion
	bob_time += delta
	var bob_y: float = sin(bob_time * 6.0) * 3.0
	if sprite_node:
		var sdb: Object = _get_sprite_db()
		if sdb:
			var data: Dictionary = sdb.get_frame(current_sprite_path, 0)
			if not data.is_empty():
				sprite_node.position = -data.offset + Vector2(0, bob_y - 4.0)

func collect(player: Node2D) -> void:
	if player != null and player.has_method("apply_item"):
		player.apply_item(item_code)
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree and (ml as SceneTree).root.has_node("AudioManager"):
		(ml as SceneTree).root.get_node("AudioManager").call("play_sfx", "Itm_ItemEaten")
	collected.emit(self, player)
	queue_free()

func incinerate() -> void:
	incinerated.emit(self)
	queue_free()
