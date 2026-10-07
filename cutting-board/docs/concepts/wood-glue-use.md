# Wood glue use: concepts

Round 1, 2026-10-07. How a wood glue use could take time, with the player mending their own
wooden body in first person. The concept page, with storyboard frames for each idea, is the
artifact https://claude.ai/artifact/Qdovd2DKHnHze2vt9CfN6F. This file is a short text copy.

Today the glue (`scenes/items/wood_glue.gd`) is used instantly from the hand; `mend()` spreads
the heal over 0.6 s in 3 steps and `MendOverlay` shows the amber glow. All three concepts play one
two-armed clip, `use_glue_both`, on the rigged arms (elbow and wrist bones).

**Recommendation: A, Forearm smear.** It keeps the view free, shows off the new arm bones, and
heals during the motion, so the existing stepped `mend()` maps onto it (method tracks instead of
the tween).

| Concept | What you see | Duration | Heals | Interrupted by | Sound |
|---|---|---|---|---|---|
| **A. Forearm smear** | Left forearm swings up with a crack; right thumb pops the lid and smears glue along it in two strokes; wrist turns, arms drop | 2.0 s | During, 3 parts (stroke 1, stroke 2, settle) | Hit before stroke 1 or sprint/jump: cancel, dab kept. Walk at half speed | pop, squelch x2, creak |
| **B. Chest crack** | View tilts ~40° down to a cracked chest plank; right hand dabs glue; left palm clamps it shut and holds; view returns | 2.8 s | At the end, all at once | Any hit or movement: cancel, dab spent. Rooted, look locked | pop, dab, clamp creak, two knocks |
| **C. Two-hand brush** | Left hand holds the pot; right hand dips a stick and paints the back of the left hand; hold to keep brushing | 1.6 s per stroke, held | During, one part per stroke | Hit or sprint stops after the current stroke | plip, swish per stroke, creak |

Open choice: whether a cancelled use keeps or spends the dab (A keeps it until the first stroke).

## Round 2: B in the engine

`tests/visual/glue_chest_concept.tscn` plays concept B in the village at night (tallow fair
lighting, PSX screen) with the first-person arm meshes, the `wood_glue_a` pot and the real
`MendOverlay` glow: tilt down 0.5 s, two dabs (glue fills the crack), left palm clamps and holds
with two knocks, heal at the end, view back up, 2.8 s in all. Mock-up only: the arms are rigid
meshes swung by tweens (an elbow bend needs the arm rig), torso and plank are placeholder boxes,
and nothing in the player or glue gameplay changed. At night the amber in the crack reads weakly,
so the real glue may want more emission. Record it with `--write-movie <out>.avi --fixed-fps 30`.

## Round 3: on the arm rig

The mock-up now instances `player.tscn` (processing off) and plays a two-armed bone animation,
`use_glue_both` (`<action>_<set>_<side>`), on its skinned arms: elbows and wrists bend, the pot
sits in `%HandSlotRight`, the left palm presses the plank, and each UpperArm cut end slides in
and down below the view while reaching, as the punches do. The keys are solved from palm targets
on the chest by a two-bone reach in the script; `--save-library` writes them to
`tests/visual/glue_use_concept_anims.tres`, ready to tune and move into `arms.tres` later. The
glue in the crack is lighter and glows (emission 1.1), so it reads at night. `arms.tres` and
player gameplay are unchanged. Still open: whether a cancelled use keeps or spends the glue.

## Round 4: in the game

`use_glue_both` now lives in `resources/animations/arms.tres` (the glue's `animation_set` is
`glue`, its Usable's `use_action` is `use`). A click with glue plays it: the arms' `view_tilt`
track tilts the camera down and back, look and movement are locked, beats fire the lid pop,
two dabs, clamp and two knocks, and the heal lands whole on the `mend` beat (2.3 s). Glue in
the left hand plays a mirrored copy, so the pot hand always dabs. A hit, or trying to move or
jump, cancels it: before the first dab (0.65 s) the glue is kept, after it the dab is spent.
