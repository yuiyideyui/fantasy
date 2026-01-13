extends Node2D

@export var growth_time: float = 2.0  # 设置为 2 秒

var current_stage: int = 0

@onready var timer = $Timer
@onready var stages = [
	$AnimatedSprite2D, 
	$AnimatedSprite2D2, 
	$AnimatedSprite2D3, 
	$AnimatedSprite2D4
]
@export var is_get_is = false
@export var description = "这棵植物正在生长中..."
func _ready():
	# 1. 初始状态：隐藏所有，只显示第一个(第0阶段)
	for s in stages:
		s.visible = false
	
	if stages.size() > 0:
		stages[0].visible = true
	
	# 2. 配置并启动计时器
	timer.wait_time = growth_time
	timer.one_shot = false # 确保它会循环触发，而不是只执行一次
	timer.start()
	
	# 注意：不要在 ready 里手动调用 _on_timer_timeout()，
	# 否则会立刻跳到下一阶段。让 timer 自己数 2 秒再触发。

func _on_timer_timeout():
	# 如果还没到最后一个阶段
	if current_stage < stages.size() - 1:
		# 隐藏旧阶段
		stages[current_stage].visible = false
		
		# 进入新阶段
		current_stage += 1
		
		# 显示新阶段
		stages[current_stage].visible = true
		# 判断是否到了最后一个阶段
		if current_stage == stages.size() - 1:
			description = "状态：已成熟。收割此植物可获得果实，食用后饥饿值恢复 10 点。"
			timer.stop()
			is_get_is = true # 标记为可以收割
			print("植物成熟了，is_get_is 现在是 true")
	else:
		# 已经长满了，停止计时
		timer.stop()
		print("植物已成熟")
