extends NavigationRegion2D

# 1. 使用 PackedScene 类型，并建议用 preload 提高性能
@onready var tree_scene: PackedScene = preload("res://tree_bodys.tscn")
# 获取生成区域节点
@onready var spawn_zone_shape = $TreeSpawnZone/CollisionShape2D 

func spawn_random_tree():
	# 检查形状
	var shape: RectangleShape2D = spawn_zone_shape.shape
	if not shape:
		print("错误：SpawnZone 必须使用 Rectangle2D 形状")
		return
	
	# 计算边界
	var rect_pos = spawn_zone_shape.position 
	var extents = shape.size / 2
	
	var x_min = rect_pos.x - extents.x
	var x_max = rect_pos.x + extents.x
	var y_min = rect_pos.y - extents.y
	var y_max = rect_pos.y + extents.y

	# 生成随机位置
	var random_pos = Vector2(
		randf_range(x_min, x_max),
		randf_range(y_min, y_max)
	)

	# 2. 关键修复：实例化 (instantiate) 而不是 duplicate
	if tree_scene:
		var new_tree = tree_scene.instantiate()
		
		# 设置位置
		new_tree.position = random_pos
		
		# 3. 建议：给新树起个唯一的临时名字，方便导出 JSON 时区分
		# 比如：tree_1705123456
		new_tree.name = "treeBodys_" + str(Time.get_ticks_msec())
		
		# 确保可见
		new_tree.show() 
		
		# 添加到场景
		$TreeSpawnZone.add_child(new_tree)
		
		print("树已生成：", new_tree.name, " 坐标：", random_pos)
	else:
		print("错误：无法加载 tree_bodys.tscn")
