class_name FactionData
extends Resource

## One side in the world — the player, villagers, bandits. Whether an NPC is friendly or
## hostile is not a kind of NPC but a relationship between two of these, which is what
## lets the same villager scene run from bandits and walk calmly past the player.

## Stable name other factions refer to this one by.
@export var id: StringName
@export var display_name: String
## Factions this one attacks on sight, or runs from, depending on the NPC. Held as ids
## rather than as FactionData references: two factions hostile to each other would
## otherwise point at each other and make a cyclic load.
@export var hostile_to: Array[StringName] = []
## Enemies to go after first, whenever one is known, however much nearer another enemy
## is. Listed in order of preference. Only affects who is attacked, not who is run from.
@export var priority_targets: Array[StringName] = []


func is_hostile_to(other: FactionData) -> bool:
	return other != null and hostile_to.has(other.id)
