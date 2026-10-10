# Blind mask death

When an NPC's mask shatters it flinches, drops what it holds, reaches both arms straight forward, gropes a few blind steps, sinks to its knees, topples face down (variant A) and dies as a ragdoll corpse.

- Result page: https://claude.ai/artifact/WAJUxhDRXqbSdjTD7ep7PL
- Game code: `scripts/npc/blind_collapse.gd` (pose sequence), played by `BodyAnimator.play_blind_collapse()` from `Npc.go_blind()`.
- At `BlindCollapse.RAGDOLL_TIME` the NPC takes silent lethal damage, so the normal death path runs (`go_limp`, loot, sounds).
- Any blow during the collapse kills it at once and it ragdolls from where it is.
- Capture scenes: `res://tests/visual/blind_mask_death_concept.tscn` (bare body) and `res://tests/visual/blind_mask_death_ingame_capture.tscn` (real bandit).
