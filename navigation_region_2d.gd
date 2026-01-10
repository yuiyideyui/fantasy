extends NavigationRegion2D

@onready var tree_template:StaticBody2D = $TreeSpawnZone/treeBodys1
# 获取你刚创建的生成区域节点
@onready var spawn_zone_shape = $TreeSpawnZone/CollisionShape2D 

func spawn_random_tree():
	# 1. 获取矩形形状的边界信息
	var shape:RectangleShape2D = spawn_zone_shape.shape
	if not shape:
		print("错误：SpawnZone 必须使用 Rectangle2D 形状")
		return
	
	# 2. 计算该区域在父节点下的实际位置范围
	# shape.size 是直径，所以要除以 2 得到半径
	var rect_pos = spawn_zone_shape.position 
	var extents = shape.size / 2
	
	var x_min = rect_pos.x - extents.x
	var x_max = rect_pos.x + extents.x
	var y_min = rect_pos.y - extents.y
	var y_max = rect_pos.y + extents.y

	# 3. 在这个特定区域内生成随机点
	var random_pos = Vector2(
		randf_range(x_min, x_max),
		randf_range(y_min, y_max)
	)

	# 4. 复制树并放置
	var new_tree = tree_template.duplicate()
	new_tree.position = random_pos
	# 确保新树也是可见的（如果你隐藏了模板）
	new_tree.show() 
	$TreeSpawnZone.add_child(new_tree)
	

	print("树已在专属区域生成：", random_pos)
