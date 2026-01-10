extends Node
class_name CharacterStats

# 定义属性的最大值
@export var max_health: float = 100.0
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0
@export var max_sanity: float = 100.0

# 定义当前值（使用 setter 确保不会超过范围）
var health: float:
	set(value):
		health = clamp(value, 0, max_health)
var hunger: float:
	set(value):
		hunger = clamp(value, 0, max_hunger)
var thirst: float:
	set(value):
		thirst = clamp(value, 0, max_thirst)
var sanity: float:
	set(value):
		sanity = clamp(value, 0, max_sanity)

func _ready():
	# 初始化：默认满值
	health = max_health
	hunger = max_hunger
	thirst = max_thirst
	sanity = max_sanity

func _process(delta):
	# 随着时间推移，饥饿和口渴会缓慢下降
	hunger -= 0.5 * delta  # 每秒掉 0.5
	thirst -= 0.8 * delta
	
	# 逻辑联动示例：如果太饿或太渴，开始扣血
	if hunger <= 0 or thirst <= 0:
		health -= 2.0 * delta
	
	# 逻辑联动示例：如果在黑暗中或饥饿，掉理智
	if hunger < 20:
		sanity -= 1.0 * delta
