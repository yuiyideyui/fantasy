# Product.gd
# Product.gd
extends Node
class_name product
# 1. 这里预载你的面板场景
var panel_scene = preload("res://panel.tscn") 
var panel_instance = null # 用来存储实例化后的面板
@onready var status = $"../stats"
# 加载你定义好的商品模板
var Bread_res = load("res://Resource/Bread.tres")
# 假设你已经按照之前的步骤，在检查器里拖入了商品 Resource
@export var inventory: Array[ItemData] = []

func _ready():
	if Bread_res:
		inventory.append(Bread_res)
func _input(event):
	if event is InputEventKey and event.keycode == KEY_P and event.pressed:
		toggle_inventory()
		
# 1. 定义枚举（作为索引）
enum ItemType { 纯净水, 食物 }
# 2. 建立一个“翻译字典”，把枚举映射到你的文件名或中文名
const ITEM_MAP = {
	ItemType.纯净水: "纯净水", # 对应 Resource/Water.tres
	ItemType.食物: "食物",  # 对应 Resource/Bread.tres
}
# 现在直接传入字符串名字，例如 "Bread"
func addProduct(type: ItemType):
	# 获取对应的文件名
	var file_name = ITEM_MAP[type]
	var path = "res://Resource/%s.tres" % file_name
	# 检查文件是否存在，防止 load 报错崩溃
	if not FileAccess.file_exists(path):
		print("错误：找不到资源文件 -> ", path)
		return

	# 2. 查找是否已经在背包里
	var index = inventory.find_custom(func(e): return e.item_name == file_name)
	
	if index != -1:
		# 如果已有，数量加 1
		inventory[index].amount += 1
		update_ui_text()
	else:
		# 如果没有，加载资源并添加
		var new_item = load(path).duplicate() # 使用 duplicate 确保该实例唯一
		# 初始化数量（如果你的 ItemData 里有这个属性）
		if "amount" in new_item:
			new_item.amount = 1
		
		inventory.append(new_item)
		update_ui_text()
			
func toggle_inventory():
	if panel_instance == null:
		panel_instance = panel_scene.instantiate()
		# 把它加到最顶层
		get_tree().root.add_child(panel_instance)
		update_ui_text()
	else:
		# 3. 如果已经创建了，就切换显示/隐藏
		panel_instance.visible = !panel_instance.visible
		if panel_instance.visible:
			update_ui_text()

func update_ui_text():
	if panel_instance == null: return
	#print('inventory[0]',inventory[0].item_name)
	# 假设你的 panel.tscn 根节点挂了上面的 ItemSlot.gd
	panel_instance.display_inventory(inventory)

# 模拟使用商品的函数
func use_item(item_data: ItemData):
	# 1. 查找物品在背包中的索引
	var index = inventory.find_custom(func(e): return e.item_name == item_data.item_name)
	
	if index != -1:
		var item_obj = inventory[index]
		
		# 2. 执行效果 (增加状态/属性)
		if status.has_method("addStatus"):
			status.addStatus(item_obj)
		
		# 3. 消耗逻辑
		# 使用 "in" 来检查 Resource 是否定义了 amount 属性
		if "amount" in item_obj:
			item_obj.amount -= 1
			
			# 4. 检查是否耗尽
			if item_obj.amount <= 0:
				inventory.remove_at(index)
				print(item_obj.item_name, " 已用完并从背包移除")
		else:
			# 如果没有 amount 属性，默认为不可堆叠物品，使用后直接移除
			inventory.remove_at(index)
		
		# 5. 更新 UI (如果有的话)
		update_ui_text()
		
	else:
		print("错误：背包中找不到物品 - ", item_data.item_name)
