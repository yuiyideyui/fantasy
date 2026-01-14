extends Node
class_name CharacterStats

# 定义属性的最大值
@export var max_health: float = 100.0
@export var max_nutrition: float = 100.0
@export var max_hydration: float = 100.0
@export var max_sanity: float = 100.0

# 定义当前值（使用 setter 确保不会超过范围）
var health: float:
	set(value):
		health = clamp(value, 0, max_health)
var nutrition: float:
	set(value):
		nutrition = clamp(value, 0, max_nutrition)
var hydration: float:
	set(value):
		hydration = clamp(value, 0, max_hydration)
var sanity: float:
	set(value):
		sanity = clamp(value, 0, max_sanity)

func _ready():
	# 初始化：默认满值
	health = max_health
	nutrition = 40
	hydration = 40
	sanity = max_sanity

func _process(delta):
	# 随着时间推移，饥饿和口渴会缓慢下降
	nutrition -= 0.3 * delta # 每秒掉 0.5
	hydration -= 0.5 * delta
	
	# 逻辑联动示例：如果太饿或太渴，开始扣血
	if nutrition <= 0 or hydration <= 0:
		health -= 2.0 * delta
	
	# 逻辑联动示例：如果在黑暗中或饥饿，掉理智
	if nutrition < 20:
		sanity -= 1.0 * delta
func addStatus(item: ItemData):
	match item.type:
		"Food":
			NetworkManager.actionText.append('使用了' + item.item_name + "，恢复了 " + item.value + "能量")
			nutrition += item.value
		"Water":
			NetworkManager.actionText.append('使用了' + item.item_name + "，恢复了 " + item.value + "含水量")
			hydration += item.value
		"Light":
			print("点亮了 ", item.item_name, "，周围变亮了")
