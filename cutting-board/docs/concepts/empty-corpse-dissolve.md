# Empty corpse dissolve

Concept for removing a dead enemy once its inventory is empty (looted). Result page: https://claude.ai/artifact/K5a3FPUFTxoug8KNQwQXiR

- A: ember dissolve. Noise burns holes through the body with a glowing edge.
- B: fall apart and sink. Ragdoll joints are switched off, limbs tumble apart, pieces sink into the ground.
- C: fall apart into sawdust. Same break-up, then each piece crumbles with a pale sawdust edge.

Shader: `assets/shaders/corpse_dissolve.gdshader` (`progress` drives the dissolve, `split` hides the stretched skin between bones so separated limbs read as loose parts).
Capture scene: `tests/visual/empty_corpse_dissolve_concept.tscn -- --variant=A|B|C`. Not wired into the game yet.
