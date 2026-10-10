class_name LoadoutRoll
extends RefCounted


static func pick_weighted(pool: Array[ItemData], weights: Array[float], none_weight: float) -> ItemData:
	var total := maxf(none_weight, 0.0)
	for i in pool.size():
		total += _weight(pool, weights, i)
	if total <= 0.0:
		return null
	var roll := randf() * total
	for i in pool.size():
		roll -= _weight(pool, weights, i)
		if roll < 0.0:
			return pool[i]
	return null


static func pick_by_chance(items: Array[ItemData], chances: Array[float]) -> Array[ItemData]:
	var picked: Array[ItemData] = []
	for i in items.size():
		var chance := chances[i] if i < chances.size() else 0.0
		if items[i] and randf() < chance:
			picked.append(items[i])
	return picked


static func _weight(pool: Array[ItemData], weights: Array[float], index: int) -> float:
	if pool[index] == null:
		return 0.0
	return maxf(weights[index], 0.0) if index < weights.size() else 1.0
