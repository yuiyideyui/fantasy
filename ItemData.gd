extends Resource
class_name ItemData # 这行非常重要，有了它你才能在新建资源时搜索到它

@export var item_name: String = "" # 商品名称
@export_enum("Food", "Water", "Seed", "Wood") var type: String = "Food" # 商品类型
@export var icon: Texture2D # 在背包里显示的图标
@export var description: String = "" # 商品描述（比如：喝了能解渴）
@export var amount: int = 1 #
# 声明变量时指定类型（强类型，会有代码补全）
# 如果是消耗品，可以加这个
@export var value: int = 10 # 恢复量（比如食物加10饱食度，灯能亮10分钟）
func to_dict() -> Dictionary:
	return {
		"name": item_name,
		"amount": amount,
		"type": type,
		"description": description
	}
