class_name DamageInfo
extends RefCounted

## One damage event, travelling from whatever dealt it to whatever receives it. Damage
## is passed as an object rather than a bare amount so that damage types, armour,
## knockback and kill credit can be added later without changing any call site.

enum Type { BLUNT, SLASH, PIERCE, FIRE }

var amount: int
var type: Type
## What is responsible for the hit — the thrown item, the attacker's body. May be null.
var source: Node
## Where the hit landed and which way it was travelling, for knockback and effects.
var position: Vector3
var direction: Vector3


func _init(p_amount: int, p_source: Node = null, p_type: Type = Type.BLUNT) -> void:
	amount = p_amount
	source = p_source
	type = p_type
