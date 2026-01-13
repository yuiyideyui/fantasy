# item_slot.gd (挂在单个格子的 Panel 上)
extends Panel

@onready var sprite = $TextureRect
@onready var label = $Label
# 提示：你可以在 Product.gd 更新文字时，顺便把物品数据存到这里
var linked_item_data: ItemData 
func update_slot(data: ItemData):
	linked_item_data = data
	# 显示图片和名字
	sprite.texture = data.icon
	label.text = data.item_name +'数量：'+ str(data.amount)
	# --- 鼠标移上去的提示 ---
	# 确保 Panel 的 Mouse Filter 是 Stop
	tooltip_text = "【%s】\n类型: %s\n描述: %s" % [data.item_name, data.type, data.description]

func _gui_input(event: InputEvent) -> void:
	# 检查是否是鼠标左键点击
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			show_confirm_dialog()

func show_confirm_dialog():
	# 这里先做一个最简单的打印提示，看看能不能点通
	print("你点击了商品：", linked_item_data.item_name)
	
	# 如果你想做一个弹窗，可以使用 Godot 自带的 ConfirmationDialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "是否使用 " + linked_item_data.item_name + " ?"
	dialog.dialog_text = linked_item_data.description
	dialog.get_ok_button().text = "是"
	dialog.get_cancel_button().text = "否"
	
	# 连接点击“确定”后的逻辑
	dialog.confirmed.connect(_on_confirmed)
	
	add_child(dialog)
	dialog.popup_centered() # 弹窗居中


# item_slot.gd 中
func _on_confirmed():
	# Get the root of the active scene tree and find the child
	var product_node = get_tree().root.find_child("product", true, false)
	
	if product_node:
		product_node.use_item(linked_item_data)
	else:
		print("Error: Could not find 'product' node in the scene tree")
