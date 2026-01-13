extends Node2D

# --- 节点引用 ---
@onready var map_root = $map
@onready var objects_roots = [
	$NavigationRegion2D/TreeSpawnZone, 
	$NavigationRegion2D/fence
]

func _ready():
	export_all_to_json()

## 主导出函数
func export_all_to_json():
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
	
	save_json_file(export_data, "ai_map_full_data.json")

# --- 实体提取（支持 Metadata 中的 description） ---
func get_static_entities(root: Node, reference_layer: TileMapLayer) -> Array:
	var entities = []
	for child in root.get_children():
		if child is Node2D:
			# 优先从脚本变量获取，如果没有，再从 Metadata 获取
			var desc = child.get("description")
			if desc == null and child.has_meta("description"):
				desc = child.get_meta("description")
			
			var info = {
				"n": child.name,
				"pixel_p": {"x": child.global_position.x, "y": child.global_position.y},
				"grid_p": null,
				"r": child.rotation,
				"description": str(desc) if desc != null else "",
				"meta": {}
			}
			
			# 坐标转换逻辑...
			if reference_layer:
				var g_pos = reference_layer.local_to_map(reference_layer.to_local(child.global_position))
				info["grid_p"] = {"x": g_pos.x, "y": g_pos.y}
			
			# 提取其余 Metadata
			for m_key in child.get_meta_list():
				if m_key != "description": # 避免重复提取
					info["meta"][m_key] = _sanitize_value(child.get_meta(m_key))
				
			entities.append(info)
	return entities
# --- 瓦片压缩（支持 Custom Data 中的 description） ---

func get_rect_compressed_map(layer: TileMapLayer) -> Array:
	var compressed_areas = []
	var used_cells = layer.get_used_cells()
	var visited = {} 
	used_cells.sort()

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
		
		var area = {
			"x": rect.position.x, "y": rect.position.y, 
			"w": rect.size.x, "h": rect.size.y,
			"description": features.get("description", "") # 提取描述
		}
		
		# 合并其余特征
		for f_key in features:
			if f_key != "description":
				area[f_key] = features[f_key]
				
		compressed_areas.append(area)
	return compressed_areas

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

func save_json_file(data: Dictionary, file_name: String):
	var file = FileAccess.open("user://" + file_name, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("--- 导出全量信息完成 ---")
		print("文件位置: ", OS.get_user_data_dir().path_join(file_name))
