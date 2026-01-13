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
	hunger -= 0.3 * delta  # 每秒掉 0.5
	thirst -= 0.5 * delta
	
	# 逻辑联动示例：如果太饿或太渴，开始扣血
	if hunger <= 0 or thirst <= 0:
		health -= 2.0 * delta
	
	# 逻辑联动示例：如果在黑暗中或饥饿，掉理智
	if hunger < 20:
		sanity -= 1.0 * delta
func addStatus(item:ItemData):
	match item.type:
		"Food":
			print("吃了 ", item.item_name, "，恢复了 ", item.value, " 点体力")
			hunger += item.value
		"Water":
			print("喝了 ", item.item_name, "，口渴度下降")
			thirst += item.value
		"Light":
			print("点亮了 ", item.item_name, "，周围变亮了")
			
