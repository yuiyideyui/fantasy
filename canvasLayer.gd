# panel.gd (挂在 panel.tscn 根节点)
extends CanvasLayer

# 预载你做好的单个商品格子的场景
var slot_scene = preload("res://panel_item_slot.tscn") 

@onready var item_grid = $ScrollContainer/ItemGrid # 记得给 GridContainer 开启唯一名称访问

func display_inventory(items: Array[ItemData]):
	# 1. 先清空旧的格子，防止重复生成
	for child in item_grid.get_children():
		child.queue_free()
	
	# 2. 循环数组，为每个商品生成一个格子
	for item in items:
		var new_slot = slot_scene.instantiate()
		item_grid.add_child(new_slot)
		
		# 3. 把数据喂给格子（调用格子的更新函数）
		if new_slot.has_method("update_slot"):
			new_slot.update_slot(item)
