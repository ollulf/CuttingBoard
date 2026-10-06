class_name NpcAction
extends Node

## One thing an NPC can decide to do. The Brain asks every action it has how much it
## wants to run right now, runs the keenest, and hands it the NPC every physics frame
## until something else wins.
##
## A new behaviour is a new subclass dropped under the Brain; nothing else has to learn
## about it. Scoring is the whole trick: an action is never told when to run, it only
## says how appealing it is, and behaviour comes out of those numbers meeting.


## How much this action wants to run, 0 for not at all. Called a few times a second,
## so it should read what the NPC knows rather than search the world.
func score(_npc: Npc) -> float:
	return 0.0


## Called once when the Brain switches to this action.
func enter(_npc: Npc) -> void:
	pass


## Called once when the Brain switches away from this action, or the NPC dies.
func exit(_npc: Npc) -> void:
	pass


## Called every physics frame while this is the running action.
func tick(_npc: Npc, _delta: float) -> void:
	pass
