# Empty corpse dissolve

Concept for removing a dead enemy once its inventory is empty (looted). Result page: https://claude.ai/artifact/K5a3FPUFTxoug8KNQwQXiR

- A: ember dissolve. Noise burns holes through the body with a glowing edge.
- B: fall apart and sink. Ragdoll joints are switched off, limbs tumble apart, pieces sink into the ground. **In the game** (round 2).
- C: fall apart into sawdust. Same break-up, then each piece crumbles with a pale sawdust edge.

Shader: `assets/shaders/corpse_dissolve.gdshader` (`progress` drives the dissolve, `split` hides the stretched skin between bones so separated limbs read as loose parts).
Capture scene: `tests/visual/empty_corpse_dissolve_concept.tscn -- --variant=A|B|C`.

## Variant B in the game

- `HumanBody.fall_apart()` swaps in the split shader (keeping the body colour), frees the joints, kicks the limbs, then turns off collision and sinks the pieces; it emits `fell_apart` when done.
- `Npc` waits `corpse_settle_time` (1.5 s) after death, then breaks the corpse up as soon as its inventory is empty and no loot window shows it (`Inventory.is_viewed()`, set by the inventory panel), and frees the NPC on `fell_apart`.
- Chair creatures have no ragdoll and keep their current death.
- Tests: `tests/corpse_breakup_check.tscn`. Clip: `tests/visual/corpse_breakup_capture.tscn`.
