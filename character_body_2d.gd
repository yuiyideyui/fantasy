extends CharacterBody2D

const SPEED = 300.0
@onready var product_instance = $"../../product"
@onready var playerAnimate = $AnimatedSprite2D
@onready var ray = $RayCast2D 
@onready var water_layer: TileMapLayer = $"../../map/WaterLayer"
@onready var attack_area: Area2D = $AttackArea
@onready var tree_template = $"../../NavigationRegion2D/TreeSpawnZone/treeBodys1"
@onready var spawn_zone_shape = $"../../NavigationRegion2D/TreeSpawnZone/CollisionShape2D"
@onready var nav_region: NavigationRegion2D = $"../../NavigationRegion2D"
# 在主角色脚本中
@onready var stats = $"../../stats"
# 1. 引用所有 UI 节点
@onready var health_bar:ProgressBar = $"../../health"  # 路径请以你拖拽生成的为准$
@onready var nutrition_bar:ProgressBar = $"../../nutrition"
@onready var hydration_bar:ProgressBar = $"../../hydration"
@onready var sanity_bar:ProgressBar = $"../../sanity"
@onready var equipment = $"../../equipment"
@onready var farmland: TileMapLayer = $"../../map/Farmland" # 引用你的耕地层

enum State { IDLE, MOVE, SURF, ATTACK, AUTO_MOVE }
var current_state = State.IDLE
signal navigation_finished
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D # 2. 获取导航节点
var last_direction = "D"
var can_check_land = false 

func _ready() -> void:
	if attack_area:
		attack_area.monitoring = false 
	
	if nav_agent and not nav_agent.velocity_computed.is_connected(_on_navigation_agent_2d_velocity_computed):
		nav_agent.velocity_computed.connect(_on_navigation_agent_2d_velocity_computed)

	# 1. 确保网格烘焙
	if nav_region:
		nav_region.bake_navigation_polygon()
	
	# 2. 等待地图彻底准备好（建议等两帧确保物理与导航同步）
	await get_tree().physics_frame
	await get_tree().physics_frame

func _process(_delta):
	# 检查 stats 和 UI 节点是否都存在，防止 null 报错
	if stats and health_bar and nutrition_bar and hydration_bar and sanity_bar:
		health_bar.value = stats.health
		nutrition_bar.value = stats.nutrition
		hydration_bar.value = stats.hydration
		sanity_bar.value = stats.sanity
	else:
		# 打印调试信息，看看到底是谁丢了
		if not stats: print("Stats 节点丢失")
		if not health_bar: print("health_bar 节点路径错误")
	
func set_movement_target(target: Vector2):
	nav_agent.target_position = target
func _physics_process(_delta: float) -> void:
	match current_state:
		State.IDLE, State.MOVE:
			handle_ground_move()
		State.SURF:
			handle_surf_move()
			if can_check_land:
				check_auto_land()
		State.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		State.AUTO_MOVE: # 4. 处理自动导航逻辑
			handle_auto_move()
	
	# 原有的 return 判断保留，但注意：下面的逻辑只有在 AUTO_MOVE 时才会执行
	if current_state != State.AUTO_MOVE:
		return
	
	# 如果导航代理认为结束了，我们依然要进一次 _on_reach_destination 以确保信号发出
	if nav_agent.is_navigation_finished():
		_on_reach_destination()
		return

	# 执行物理移动
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	velocity = direction * 150.0 
	move_and_slide()
	
	# --- 改进的“到达”判定逻辑 ---
	var dist_to_target = global_position.distance_to(nav_agent.target_position)
	
	# 条件 A: 引擎判定触发 | 条件 B: 足够近（解决重叠） | 条件 C: 卡死挤压判定
	if nav_agent.is_target_reached() or dist_to_target < 10.0:
		_on_reach_destination()
	elif velocity.length() < 10.0 and dist_to_target < 20.0:
		_on_reach_destination()

func _on_reach_destination():
	# 只有在 AUTO_MOVE 状态下才处理到达逻辑，防止重复触发
	if current_state == State.AUTO_MOVE:
		velocity = Vector2.ZERO
		current_state = State.IDLE
		nav_agent.target_position = global_position 
		navigation_finished.emit() 
		print("到达目的地/目标重叠区域，发送完成信号")

# --- 触发自动导航的方法 ---
func start_auto_navigation(target_pos: Vector2):
	var map_rid = get_world_2d().get_navigation_map()
	var safe_pos = NavigationServer2D.map_get_closest_point(map_rid, target_pos)
	
	if safe_pos.distance_to(target_pos) > 32.0:
		print("警告：目标点被遮挡，已修正至最近的可通行位置")

	current_state = State.AUTO_MOVE
	nav_agent.target_position = safe_pos

# --- 自动导航移动逻辑 ---
func handle_auto_move():
	var next_path_pos = nav_agent.get_next_path_position()
	
	# 如果距离非常近，跳过避障直接让下方 move_and_slide 处理
	if global_position.distance_to(next_path_pos) < 3.0:
		return

	var direction = (next_path_pos - global_position).normalized()

	if nav_agent.avoidance_enabled:
		# 如果启用了避障，建议在这里处理信号回调，如果不启用，下方逻辑会处理 velocity
		nav_agent.set_velocity(direction * 150.0)
	else:
		# 这里只处理动画，不改动 velocity，因为下方统一执行 move_and_slide
		update_walk_animation(direction)
# --- 陆地移动 ---
func handle_ground_move():
	var direction := Input.get_vector("walkL", "walkR", "walkU", "walkD")
	if direction != Vector2.ZERO:
		current_state = State.MOVE
		velocity = direction * SPEED
		update_walk_animation(direction)
		update_ray_direction() 
		update_attack_area_position() # 实时更新攻击框位置
	else:
		current_state = State.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		play_static_animation()

# --- 冲浪逻辑 ---
func handle_surf_move():
	var direction := Input.get_vector("walkL", "walkR", "walkU", "walkD")
	velocity = direction * SPEED
	if direction != Vector2.ZERO:
		update_walk_animation(direction)
		update_ray_direction()
		update_attack_area_position()
	else:
		play_static_animation()

func check_auto_land():
	if not water_layer: return
	var map_pos = water_layer.local_to_map(water_layer.to_local(global_position))
	var tile_data = water_layer.get_cell_tile_data(map_pos)
	if tile_data == null:
		exit_surfing_status()

# --- 输入处理 ---
func _input(event: InputEvent) -> void:
	if current_state == State.ATTACK: return

	# 测试按键：按下键盘 'G' 键自动去 (50, 350)
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		start_auto_navigation(Vector2(50, 350))

	# 如果玩家手动输入移动，中断自动导航
	if event.is_action_pressed("walkL") or event.is_action_pressed("walkR") or \
	   event.is_action_pressed("walkU") or event.is_action_pressed("walkD"):
		if current_state == State.AUTO_MOVE:
			current_state = State.IDLE

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		try_surf()
	
	if event.is_action_pressed("att") and not event.is_echo():
		play_att_animation()
	# 假设玩家按下鼠标左键，且手里拿着锄头
	if event.is_action_pressed("interact"):
		perform_interaction()
		
func perform_interaction():
	var foot_pos = global_position + Vector2(0, 5)
	var map_pos = farmland.local_to_map(farmland.to_local(foot_pos))
	var tile_data = farmland.get_cell_tile_data(map_pos)

	if not tile_data:
		print("这里什么都没有")
		return

	# 模式匹配：一个按键，多种用途
	if tile_data.get_custom_data("is_water"):
		get_water()
	elif tile_data.get_custom_data("is_farmland"):
		plant_at_player_position(map_pos)
		
func get_water():
	# 播放取水动画
	product_instance.addProduct(product_instance.ItemType.纯净水)
	print("装满了水壶")
func plant_at_player_position(map_pos):
	# 检查是否已经种了东西（复用之前的检测函数）
	var is_farmland = get_plant_at_pos(map_pos)
	if not is_instance_valid(is_farmland):
		spawn_crop(map_pos)
		print("种植成功！")
	else:
		if is_farmland.is_get_is:
			print("植物成熟了")
			do_harvest(is_farmland)
		else:
			print("植物还没熟呢，不能收！")
# 辅助函数：通过坐标检查该位置是否已经有植物了
func get_plant_at_pos(map_pos: Vector2i):
	# 获取所有属于 "crop_instances" 组的节点
	for crop in get_tree().get_nodes_in_group("crop_instances"):
		# 检查这个植物身上存的地图坐标是否等于我们当前检测的坐标
		if crop.has_meta("map_pos") and crop.get_meta("map_pos") == map_pos:
			return crop
	return null
# 收割逻辑
func do_harvest(plant):
	product_instance.addProduct(product_instance.ItemType.食物)
	# 这里可以给玩家加金币或物品
	plant.queue_free() # 移除植物
func spawn_crop(map_pos: Vector2i):
	var crop_scene = preload("res://Wheat.tscn")
	var crop = crop_scene.instantiate()
	
	# 1. 直接加到 farmland 下，这样 crop 的 position 就是相对于地图格子的了
	farmland.add_child(crop)
	
	# 2. 使用 map_to_local，它会返回该格子在 TileMap 内部的中心点位置
	crop.position = farmland.map_to_local(map_pos)
	
	# 3. 强制提高 Z 索引，防止被地块遮挡
	crop.z_index = 5 
	
	# 4. 打标签和元数据
	crop.add_to_group("crop_instances")
	crop.set_meta("map_pos", map_pos)
	
	print("植物已生成在格子坐标：", map_pos, " 相对位置：", crop.position)
func try_surf():
	ray.force_raycast_update()
	if current_state != State.SURF:
		if is_facing_water(): start_surfing()
	else:
		if ray.is_colliding() and ray.get_collider() != water_layer:
			stop_surfing()

func is_facing_water() -> bool:
	return ray.is_colliding() and ray.get_collider() == water_layer

# --- 状态过渡 ---
func start_surfing():
	current_state = State.SURF
	can_check_land = false
	set_collision_mask_value(3, false) 
	var jump_offset = ray.target_position.normalized() * 32.0
	var tween = create_tween()
	tween.tween_property(self, "position", position + jump_offset, 0.2)
	tween.finished.connect(func(): can_check_land = true)
	modulate = Color(0.5, 0.8, 1.0); z_index = 1

func stop_surfing():
	can_check_land = false
	var jump_offset = ray.target_position.normalized() * 32.0
	var tween = create_tween()
	tween.tween_property(self, "position", position + jump_offset, 0.2)
	tween.finished.connect(exit_surfing_status)

func exit_surfing_status():
	current_state = State.IDLE; can_check_land = false
	set_collision_mask_value(3, true); modulate = Color.WHITE; z_index = 0

# --- 核心：攻击与砍树 ---
func play_att_animation() -> void:
	attack_area.monitoring = true
	current_state = State.ATTACK
	var anim_name = "attU" if last_direction == "U" else ("attD" if last_direction == "D" else "attR")
	playerAnimate.flip_h = (last_direction == "L")
	playerAnimate.play(anim_name)
	
	# 1. 强制更新 Area2D 的位置并刷新物理探测
	update_attack_area_position()
	attack_area.force_update_transform()
	
	# 2. 等待极短的时间（物理帧）确保检测生效
	await get_tree().physics_frame
	
	var bodies = attack_area.get_overlapping_bodies()
	print("检测到物体数量: ", bodies.size(),equipment.get_total_stats().attack)
	
	for body in bodies:
		# 建议给树节点加一个 cut 方法，或者保持你的 group 判断
		if body.has_method("cut"):
			body.cut(equipment.get_total_stats().attack) # 调用我们之前写的带血量和动画的函数
			attack_area.monitoring = true
			break 

	await playerAnimate.animation_finished
	if current_state == State.ATTACK:
		current_state = State.IDLE
# --- 辅助函数 ---
func update_attack_area_position():
	var offset_dist = 15.0 # 稍微短一点，确保能碰到
	match last_direction:
		"U": attack_area.position = Vector2(0, -offset_dist)
		"D": attack_area.position = Vector2(0, offset_dist)
		"L": attack_area.position = Vector2(-offset_dist, 0)
		"R": attack_area.position = Vector2(offset_dist, 0)

func update_ray_direction():
	var offset = 25
	match last_direction:
		"L": ray.target_position = Vector2(-offset, 0)
		"R": ray.target_position = Vector2(offset, 0)
		"U": ray.target_position = Vector2(0, -offset)
		"D": ray.target_position = Vector2(0, offset)

func update_walk_animation(dir: Vector2) -> void:
	if abs(dir.x) >= abs(dir.y):
		playerAnimate.play("walkR")
		playerAnimate.flip_h = (dir.x < 0)
		last_direction = "L" if dir.x < 0 else "R"
	else:
		playerAnimate.flip_h = false
		if dir.y < 0:
			playerAnimate.play("walkU"); last_direction = "U"
		else:
			playerAnimate.play("walkD"); last_direction = "D"

func play_static_animation() -> void:
	playerAnimate.flip_h = (last_direction == "L")
	var suffix = "R" if (last_direction == "L" or last_direction == "R") else last_direction
	playerAnimate.play("static" + suffix)


func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	if current_state == State.AUTO_MOVE:
		velocity = safe_velocity
		# 根据避障修正后的实际移动方向来更新动画，这样更准确
		if velocity.length() > 10.0: 
			update_walk_animation(velocity.normalized())
		move_and_slide()
