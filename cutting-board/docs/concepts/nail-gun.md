# Nail gun concepts: shed-built one-shot guns

Round 1, 2026-10-07. Five mechanical (not electric) nail guns that a wooden puppet could have
knocked together in a shed. Each fires one nail, takes nails from the inventory as ammo and has
to be re-armed by hand after every shot. The result page with the line-up, close shots and
in-hand shots is https://claude.ai/artifact/8MAFRARVAHjYHnSqyVSspU. This file is a short copy.

Models: `tools/import/build_nail_guns.gd` writes `assets/meshes/props/nail_gun_*.res` (laid out
like the saw: grip at the origin along +Y, barrel along -Z). Photos:
`tests/visual/nail_gun_capture.tscn -- --shots=<dir> [--plain]`.

## Recommended: A, Lever Bolt

One big readable rearm stroke (a single new arm animation), reads well at PSX resolution, and its
stats sit beside the hammer and saw rather than above them.

## The guns

| | Rearm (first person) | Load | Damage | Rearm | Range | Sound |
|---|---|---|---|---|---|---|
| **A Lever Bolt**: pipe barrel lashed to a plank, coil spring and wooden bolt, under-lever | Left hand slaps the lever forward and hauls it back under the grip | Nail dropped into the muzzle, tapped home | 3 | 0.9 s | 12 m | lever creak, spring zing, peg clack; thunk, nail whistle |
| **B Rope Twister**: torsion crossbow, twisted rope skeins, sled, windlass | Left hand cranks the windlass three turns | Nail laid in the groove before the sled | 4 | 1.6 s | 18 m | rope creak, ratchet clicks; deep twang |
| **C Band Catapult**: forked branch, two rubber bands, leather pouch striker, clothes-peg latch | Left hand pinches the pouch back to the peg | Nail set in the metal channel | 2 | 0.6 s | 9 m | rubber squeak, peg snap; thwap |
| **D Bellows Puffer**: hinged boards with a leather gusset under a pipe | Left hand lifts the knob, pumping the bellows open | Nail pushed into the muzzle | 1.5 + knockback | 1.2 s | 6 m | wheeze in; whoomph, dusty cough |
| **E Clockwork Knocker**: wound drum, wind-up key, cog, striker arm | Left hand twists the key four quarter-turns | Nail slid in under the striker | 2.5 | 2.0 s | 10 m | ratchet clicks, tick-tick; clank |

## What implementing one would need

- A stackable nail `ItemData` in the inventory, and a way for a held item to take one from it.
- A ranged weapon component on the gun's item scene: states empty / loaded / armed; attack fires
  only when loaded and armed, then goes back to empty.
- A nail projectile: a small `RigidBody3D` with `ImpactDamage` that sticks into wood on hit, and
  can be picked up again as ammo.
- A rearm action (attack while not armed, or its own key) that plays a new two-handed arm
  animation and consumes one nail.
- The held item scene with its mesh tilt per gun, sound effects, and a small loaded/armed cue.
