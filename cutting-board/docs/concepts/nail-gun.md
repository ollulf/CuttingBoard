# Nail gun concepts: shed-built one-shot guns

Two rounds, 2026-10-07. Mechanical (not electric) nail launchers a wooden puppet could have
knocked together in a shed. Each takes its nails from the inventory as ammo and has to be
re-armed by hand after every shot. The result page (line-ups, close shots, in-hand shots) is
https://claude.ai/artifact/8MAFRARVAHjYHnSqyVSspU. This file is a short copy.

Models: `tools/import/build_nail_guns.gd` writes `assets/meshes/props/nail_gun_*.res` and the
round 2 ammo `nail_ammo_*.res` (laid out like the saw: grip at the origin along +Y, barrel along
-Z). Photos: `tests/visual/nail_gun_capture.tscn -- --shots=<dir> [--round=2] [--plain]`.

## Round 2: blunderbusses with big nails

Feedback: think blunderbuss, bigger nails, it doesn't have to look like a gun. Ammo is now a
railroad spike (about a hand long) or a fistful of coffin nails (one and a half times a round 1
nail, much thicker).

### Recommended: F, Log Bombard

The clearest blunderbuss read (flared mouth, hoops), a short-range spread that suits a slow
one-shot, and one strong two-handed rearm motion (haul the rope toggle back).

| | Rearm (first person) | Load | Damage | Spread | Rearm | Range | Sound |
|---|---|---|---|---|---|---|---|
| **F Log Bombard**: hollowed log with a flared mouth, iron hoops, spring ram on a rope toggle | Left hand grabs the toggle behind the log and hauls it back to the catch | Fistful of 5 coffin nails pushed into the mouth | 5 x 1.5 | 25 deg cone | 1.4 s | 7 m | rope creak, spring groan, catch clack; deep wooden boom, nails rattle |
| **G Churn Thumper**: butter churn on its side, dasher pulled back against inner-tube straps | Left hand drags the cross handle back until the latch drops | One railroad spike slid into the lid hole | 7 | none | 1.6 s | 14 m | rubber stretch, latch clunk; heavy thump, spike whirr |
| **H Bellows Horn**: hearth bellows with a tin funnel horn | Left hand pulls the top board's handle up, opening the bellows | 4 coffin nails dropped into the horn | 4 x 1 + knockback | 35 deg cone | 1.0 s | 5 m | leather wheeze in; whoomph, tin clang, nails scatter |
| **I Keg Cranker**: nail keg as a hopper on a stock, side crank, flat spring | Left hand turns the crank one full turn | Spikes tipped into the keg (holds 6), one drops per turn | 6 | none | 1.2 s | 12 m | keg rattle, ratchet clicks, spring tick; clank, spike whirr |
| **J Trough Swinger**: nailing trough with a mallet on a springy ash arm | Left hand pulls the mallet up and back onto the hook | One spike laid in the trough | 8 | none | 2.0 s | 10 m | ash arm creak, hook clink; mallet whack, trough rattle |

## Round 1: pistol-sized nail guns

Recommended then: A, Lever Bolt (one big readable rearm stroke).

| | Rearm (first person) | Load | Damage | Rearm | Range | Sound |
|---|---|---|---|---|---|---|
| **A Lever Bolt**: pipe barrel lashed to a plank, coil spring and wooden bolt, under-lever | Left hand slaps the lever forward and hauls it back under the grip | Nail dropped into the muzzle, tapped home | 3 | 0.9 s | 12 m | lever creak, spring zing, peg clack; thunk, nail whistle |
| **B Rope Twister**: torsion crossbow, twisted rope skeins, sled, windlass | Left hand cranks the windlass three turns | Nail laid in the groove before the sled | 4 | 1.6 s | 18 m | rope creak, ratchet clicks; deep twang |
| **C Band Catapult**: forked branch, two rubber bands, leather pouch striker, clothes-peg latch | Left hand pinches the pouch back to the peg | Nail set in the metal channel | 2 | 0.6 s | 9 m | rubber squeak, peg snap; thwap |
| **D Bellows Puffer**: hinged boards with a leather gusset under a pipe | Left hand lifts the knob, pumping the bellows open | Nail pushed into the muzzle | 1.5 + knockback | 1.2 s | 6 m | wheeze in; whoomph, dusty cough |
| **E Clockwork Knocker**: wound drum, wind-up key, cog, striker arm | Left hand twists the key four quarter-turns | Nail slid in under the striker | 2.5 | 2.0 s | 10 m | ratchet clicks, tick-tick; clank |

## What implementing one would need

- A stackable ammo `ItemData` in the inventory (nail, coffin nails or railroad spike), and a way
  for a held item to take one from it.
- A ranged weapon component on the gun's item scene: states empty / loaded / armed; attack fires
  only when loaded and armed, then goes back to empty.
- A projectile: a small `RigidBody3D` with `ImpactDamage` that sticks into wood on hit, and can
  be picked up again as ammo. The spread guns (F, H) fire several at once in a cone.
- A rearm action (attack while not armed, or its own key) that plays a new two-handed arm
  animation and consumes the ammo.
- The held item scene with its mesh tilt per gun, sound effects, and a small loaded/armed cue.
