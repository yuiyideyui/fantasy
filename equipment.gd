extends Node2D

# 装备槽位定义
enum Slot {
	MAIN_HAND,  # 主手（武器）
	OFF_HAND,   # 副手（盾牌/法器）
	HEAD,       # 头部
	BODY,       # 身体
	ACCESSORY   # 饰品
}

# 简单的物品数据类
class Item:
	var name: String
	var slot: Slot
	var stats: Dictionary = {} # 格式: {"attack": 10, "defense": 5}

	func _init(p_name: String, p_slot: Slot, p_stats: Dictionary = {}):
		name = p_name
		slot = p_slot
		stats = p_stats

# 当前已装备的物品容器 { Slot: Item }
var equipment_slots: Dictionary = {}

func _ready() -> void:
	# --- 测试代码 ---
	print("--- 装备系统初始化 ---")
	
	# 1. 创建一把剑
	var sword = Item.new("新手铁剑", Slot.MAIN_HAND, {"attack": 10})
	equip(sword)
	
	# 2. 创建一个盾牌
	var shield = Item.new("木盾", Slot.OFF_HAND, {"defense": 5, "max_health": 20})
	equip(shield)
	
	# 3. 打印当前总属性
	print("当前装备总属性: ", get_total_stats())
	
	# 4. 替换测试：装备一把更强的剑
	var strong_sword = Item.new("火焰剑", Slot.MAIN_HAND, {"attack": 50, "crit_rate": 0.1})
	print("更换武器...")
	equip(strong_sword)
	print("更换后总属性: ", get_total_stats())
	
	print("--- 装备系统测试结束 ---")

# 装备物品
func equip(item: Item) -> void:
	# 如果该槽位已有物品，先卸下
	if equipment_slots.has(item.slot):
		unequip(item.slot)
	
	equipment_slots[item.slot] = item
	print("已装备: %s (槽位: %s)" % [item.name, Slot.keys()[item.slot]])
	# 这里可以发送信号，通知 UI 或 角色更新属性
	# emit_signal("equipment_changed")

# 卸下物品
func unequip(slot: Slot) -> void:
	if equipment_slots.has(slot):
		var item = equipment_slots[slot]
		equipment_slots.erase(slot)
		print("已卸下: %s" % item.name)
	else:
		print("槽位 %s 为空，无法卸下" % Slot.keys()[slot])

# 获取所有装备提供的属性总和
func get_total_stats() -> Dictionary:
	var total_stats = {}
	
	for slot in equipment_slots:
		var item = equipment_slots[slot]
		for stat_name in item.stats:
			var value = item.stats[stat_name]
			if total_stats.has(stat_name):
				total_stats[stat_name] += value
			else:
				total_stats[stat_name] = value
				
	return total_stats
