extends Node2D

# --- 节点引用 ---
@onready var map_root = $map
@onready var objects_roots = [
	$NavigationRegion2D/TreeSpawnZone,
	$NavigationRegion2D/fence
]
@onready var player_status = $stats
@onready var player = $player/CharacterBody2D
@onready var product = $product
func _ready():
	export_all_to_json()

## 主导出函数
func export_all_to_json(getOrSend = false):
	var export_data = {
		"export_time": Time.get_datetime_string_from_system(),
		"map_layers": {},
		"entities": []
	}
	
	# 1. 处理瓦片地图层
	var first_layer: TileMapLayer = null
	if map_root:
		for layer in map_root.get_children():
			if layer is TileMapLayer:
				if not first_layer: first_layer = layer
				export_data["map_layers"][layer.name] = get_rect_compressed_map(layer)
	
	# 2. 遍历物体容器
	for root in objects_roots:
		if root:
			var root_entities = get_static_entities(root, first_layer)
			export_data["entities"].append_array(root_entities)
	export_data['player_status'] = {
		"nutrition": player_status.nutrition,
		"health": player_status.health,
		"hydration": player_status.health,
		"sanity": player_status.sanity,
		"pos": {"grid_x": player.global_position.x, "grid_y": player.global_position.y},
		"inventory": {
			"capacity": 20,
			"used": 5,
			"items": product.inventory.map(func(i): return i.to_dict())
		}
	}
	if (getOrSend):
		NetworkManager.sendData = export_data
		NetworkManager.send_data(export_data)
		return
	save_and_sync_ai(export_data)

# --- 实体提取（支持 Metadata 并解析 CollisionShape2D 获取尺寸） ---
func get_static_entities(root: Node, reference_layer: TileMapLayer) -> Array:
	var entities = []
	for child in root.get_children():
		if child is Node2D:
			# 1. 优先从脚本变量获取描述，其次 Metadata
			var desc = child.get("description")
			if desc == null and child.has_meta("description"):
				desc = child.get_meta("description")
			
			# 2. 获取尺寸 w 和 h (通过 CollisionShape2D)
			var size = _get_collision_size(child)
			
			var info = {
				"n": child.name,
				"pixel_p": {"x": child.global_position.x, "y": child.global_position.y},
				"grid_p": null, # 预留网格坐标
				"w": size.x,
				"h": size.y,
				"r": child.rotation,
				"description": str(desc) if desc != null else "",
				"meta": {}
			}

			# 3. 计算网格坐标 (保留你之前的逻辑)
			if reference_layer:
				var g_pos = reference_layer.local_to_map(reference_layer.to_local(child.global_position))
				info["grid_p"] = {"x": int(g_pos.x), "y": int(g_pos.y)}

			# 4. 提取其余 Metadata
			for m_key in child.get_meta_list():
				if m_key != "description":
					info["meta"][m_key] = _sanitize_value(child.get_meta(m_key))
				
			entities.append(info)
	return entities

# --- 辅助函数：解析碰撞体形状获取尺寸 ---
func _get_collision_size(entity: Node2D) -> Vector2:
	for child in entity.get_children():
		if child is CollisionShape2D and child.shape:
			var s = child.shape
			if s is RectangleShape2D:
				# RectangleShape2D 的 extents 是中心到边的距离，所以要乘以 2
				return s.size
			elif s is CircleShape2D:
				# 圆形则返回直径
				return Vector2(s.radius * 2, s.radius * 2)
			elif s is CapsuleShape2D:
				return Vector2(s.radius * 2, s.height)
	
	# 如果没有碰撞体，返回默认值或 0
	return Vector2(0, 0)
# --- 瓦片压缩（支持 Custom Data 中的 description） ---
func get_rect_compressed_map(layer: TileMapLayer) -> Dictionary:
	var compressed_areas = []
	var used_cells = layer.get_used_cells()
	var visited = {}
	used_cells.sort()

	# --- 1. 获取图层全局描述 ---
	# 这里假设你把描述写在了节点的 Meta 里，或者直接用节点名字
	# 你也可以改为手动传入一个参数
	var layer_description = layer.get_meta("description", layer.name)

	var custom_names = []
	if layer.tile_set:
		for i in range(layer.tile_set.get_custom_data_layers_count()):
			custom_names.append(layer.tile_set.get_custom_data_layer_name(i))

	for cell in used_cells:
		if visited.has(cell): continue
		
		var features = _get_tile_features(layer, cell, custom_names)
		var rect = _expand_rect(layer, cell, features, custom_names, visited)
		
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				visited[Vector2i(x, y)] = true
		
		# --- 2. 区域数据不再包含 description ---
		var area = {
			"x": rect.position.x,
			"y": rect.position.y,
			"w": rect.size.x,
			"h": rect.size.y
		}
		
		# 合并其余特征 (Custom Data)
		for f_key in features:
			# 如果你的 CustomData 里确实没写 description，这里就不用判断
			area[f_key] = features[f_key]
				
		compressed_areas.append(area)

	# --- 3. 返回包含全局信息的字典 ---
	return {
		"layer_name": layer.name,
		"description": layer_description,
		"areas": compressed_areas
	}

func _get_tile_features(layer: TileMapLayer, pos: Vector2i, names: Array) -> Dictionary:
	var f = {}
	var data = layer.get_cell_tile_data(pos)
	for n in names:
		f[n] = _sanitize_value(data.get_custom_data(n)) if data else null
	return f

func _expand_rect(layer: TileMapLayer, start: Vector2i, target_f: Dictionary, names: Array, visited: Dictionary) -> Rect2i:
	var w = 1; var h = 1
	while _check_match(layer, start + Vector2i(w, 0), target_f, names) and not visited.has(start + Vector2i(w, 0)):
		w += 1
	while true:
		var ok = true
		for x in range(w):
			var c = start + Vector2i(x, h)
			if not _check_match(layer, c, target_f, names) or visited.has(c):
				ok = false; break
		if ok: h += 1
		else: break
	return Rect2i(start, Vector2i(w, h)) # 修正之前的变量名 bug，此处应为 w, h

# 为了防止变量名在某些版本中混淆，这里修正下：
func _expand_rect_fixed(layer: TileMapLayer, start: Vector2i, target_f: Dictionary, names: Array, visited: Dictionary) -> Rect2i:
	var tw = 1; var th = 1
	while _check_match(layer, start + Vector2i(tw, 0), target_f, names) and not visited.has(start + Vector2i(tw, 0)):
		tw += 1
	while true:
		var ok = true
		for x in range(tw):
			var c = start + Vector2i(x, th)
			if not _check_match(layer, c, target_f, names) or visited.has(c):
				ok = false; break
		if ok: th += 1
		else: break
	return Rect2i(start, Vector2i(tw, th))

func _check_match(layer: TileMapLayer, pos: Vector2i, target_f: Dictionary, names: Array) -> bool:
	if layer.get_cell_source_id(pos) == -1: return false
	return _get_tile_features(layer, pos, names) == target_f

func _sanitize_value(val):
	if val is Color: return val.to_html()
	if val is Vector2 or val is Vector2i: return {"x": val.x, "y": val.y}
	return val

func save_and_sync_ai(data: Dictionary):
	# 1. 保留原本的存盘功能（可选，用于调试）
	save_json_file(data, "test.json")
	# 2. 通过 WebSocket 实时推送
	if NetworkManager.is_connected_to_server:
		NetworkManager.send_data(data)
	else: NetworkManager.sendData = data
		
func save_json_file(data: Dictionary, file_name: String):
	var file = FileAccess.open("user://" + file_name, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("--- 导出全量信息完成 ---")
		print("文件位置: ", OS.get_user_data_dir().path_join(file_name))
