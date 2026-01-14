extends Node

# --- 变量定义 ---
var socket = WebSocketPeer.new()
var url = "ws://127.0.0.1:8765" # 你的 Python 服务器地址
var is_connected_to_server = false
var sendData: Dictionary = {}

# 动态引用的节点变量
var player: CharacterBody2D = null
var product: Node = null

var actionText: Array = []

# --- 生命周期方法 ---
func _ready():
	# 尝试连接服务器
	var err = socket.connect_to_url(url)
	if err != OK:
		print("无法发起连接: ", err)
		set_process(false)

func _process(_delta):
	socket.poll() # 必须每帧轮询以维持连接
	
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_server:
			print("WebSocket 已连接到服务器！")
			is_connected_to_server = true
			# 第一次连接成功时，如果已有初始数据则发送
			if sendData.size() > 0:
				send_data(sendData)
			else:
				# 或者主动触发一次初始环境扫描
				_trigger_export()
				
		# 读取服务器传回的消息（AI 的决策动作）
		while socket.get_available_packet_count() > 0:
			_on_data_received(socket.get_packet().get_string_from_utf8())
			
	elif state == WebSocketPeer.STATE_CLOSED:
		is_connected_to_server = false

# --- 通信核心 ---
func send_data(data: Dictionary):
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("发送失败：未连接到服务器")
		return
	# 将当前的 actionText 添加到数据中 action响应Text
	data['responeText'] = actionText
	var json_string = JSON.stringify(data)
	socket.send_text(json_string)
	print("--- 数据已通过 WebSocket 推送 ---")

# 接收 AI 的决策 - 异步等待队列模式
func _on_data_received(payload: String):
	var json = JSON.new()
	var error = json.parse(payload)
	
	if error == OK:
		var data = json.data
		print("收到 AI 决策: ", data.get("thought", ""))
		# 初始化文案
		actionText = ''
		var actions = data.get("actions", [])
		
		# 依次顺序执行动作
		for action in actions:
			# 1. 执行当前动作（如移动，会在这里等待直到到达目的地）
			await _execute_action(action)
			
			# 2. 【新增逻辑】每个动作执行完后，强制停顿 1 秒再执行下一个或回传数据
			print("动作完成，停顿 1 秒...")
			await get_tree().create_timer(1.0).timeout
		
		# --- 关键：所有 actions 执行并停顿完后，才统一返回最新的感知数据 ---
		print("所有指令及停顿执行完毕，正在回传感知数据...")
		_trigger_export()
	else:
		print("解析服务器数据失败")

# --- 逻辑控制 ---

# 动作分发器 - 使用 await 确保顺序性
func _execute_action(action: Dictionary) -> void:
	if not _refresh_references():
		print("警告：AI 动作执行失败，组件未就绪")
		return

	var type = action.get("type")
	match type:
		"move_to":
			# 等待移动动作发出信号（到达目的地）后再继续
			await move_fn(action.get("x"), action.get("y"))
		"use":
			# 执行即时动作
			use_fn(action.get("item"))
			# 内部微小缓冲
			await get_tree().create_timer(0.2).timeout
		"attack":
			# 执行攻击/交互逻辑
			attack_fn(int(action.get("sum", 1)))
			await get_tree().create_timer(0.2).timeout
		_:
			# 未知动作默认缓冲
			await get_tree().create_timer(0.1).timeout

# 攻击/交互函数
func attack_fn(x: int):
	print('attack')
	# 调用玩家脚本中的交互方法
	if player and player.has_method("play_att_animation"):
		player.play_att_animation()

# 移动函数 - 包含坐标修正和异步等待信号
func move_fn(x: float, y: float) -> void:
	# 1. 坐标修正逻辑
	var map_rid = player.get_world_2d().get_navigation_map()
	var target_pos = Vector2(x, y)
	var safe_pos = NavigationServer2D.map_get_closest_point(map_rid, target_pos)
	
	print("AI 指令：开始移动至 ", safe_pos)
	player.start_auto_navigation(safe_pos)
	
	# 2. 【核心】等待玩家脚本发出的 navigation_finished 信号
	if player.has_signal("navigation_finished"):
		await player.navigation_finished
		print("玩家已到达目的地信号")
	else:
		print("错误：玩家 CharacterBody2D 缺少信号定义，启用 2秒兜底")
		await get_tree().create_timer(2.0).timeout

# 使用函数
func use_fn(item_name: String):
	print("AI 指令：执行使用 ", item_name)
	if product.has_method("use_item"):
		product.use_item(item_name)

# --- 辅助功能 ---

# 统一触发数据导出
func _trigger_export():
	var root = get_tree().current_scene
	if root and root.has_method("export_all_to_json"):
		# 这里获取整个游戏世界的感知数据，最后回调 -> send_data
		root.export_all_to_json(true)

# 动态查找组件引用
func _refresh_references() -> bool:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	
	if not is_instance_valid(product):
		product = get_tree().get_first_node_in_group("product")
		if not product and player:
			product = player.get_node_or_null("product")
			
	return is_instance_valid(player) and is_instance_valid(product)
