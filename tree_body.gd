extends StaticBody2D

@export var max_health: int = 130
var current_health: int = max_health

@onready var navigation_region = $"../.."
@onready var sprite = $Sprite2D # 确保你的树有 Sprite2D 节点
func cut(attack):
	# 减少生命值
	current_health -= attack
	NetworkManager.actionText.append('攻击了这棵树树剩余血量' + current_health)
	if current_health <= 0:
		die()
	else:
		play_hit_effect()

func play_hit_effect():
	# 受击效果：闪红 + 左右晃动
	var tween = create_tween()
	
	# 1. 变成红色并恢复
	sprite.modulate = Color.RED
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	# 2. 左右晃动效果 (Tween)
	var original_pos = sprite.position
	var shake_tween = create_tween()
	shake_tween.tween_property(sprite, "position", original_pos + Vector2(3, 0), 0.05)
	shake_tween.tween_property(sprite, "position", original_pos - Vector2(3, 0), 0.05)
	shake_tween.tween_property(sprite, "position", original_pos, 0.05)
func die():
	print("树被砍倒了！")
	
	# 1. 立即禁用碰撞，这样下一帧寻路算法如果重新计算，虽然网格还没变，但避障可能已经不考虑它了
	$CollisionShape2D.set_deferred("disabled", true)
	
	var tween = create_tween().set_parallel(true)
	var direction = 1 if randf() > 0.5 else -1
	
	tween.tween_property($Sprite2D, "rotation", deg_to_rad(90 * direction), 0.5) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	
	# 3. 通知生成新树（新树生成后，由生成函数触发一次 bake）
	if navigation_region and navigation_region.has_method("spawn_random_tree"):
		navigation_region.spawn_random_tree()
	
	# 4. 关键：在树彻底销毁后，触发导航网格重新烘培
	# 我们把 bake 放在链式调用的最后
	tween.chain().tween_callback(queue_free)
	# 重点：树销毁后，通知父级或导航区域重绘，这样“红线”就会变直
	tween.chain().tween_callback(func():
		if navigation_region:
			navigation_region.bake_navigation_polygon()
	)
