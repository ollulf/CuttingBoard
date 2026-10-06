# Pause menu concept: Mask Off

Interactive mock-ups: https://claude.ai/artifact/NQQUSk7T78K7JDUBvSkj76

Pause = the first-person hands lift the mask off the face (the screen starts as the inside of the
mask, seen through its eye holes). The menu is on the mask. Choosing an option carves a knife
groove through it, with shavings; Resume (or pause again) puts the mask back on.

- **A, carved list:** the mask stays inside-out; options carved as words under the eye holes.
  Best readability at 320x240, plain d-pad navigation, room for 5-7 entries.
- **B, the face is the menu:** the mask turns to face you; mouth Resume, eyes Save/Load, nose
  Settings, brow Quit. Most charm, about 5 slots max, needs a caption plank for the words.
- **C, tabs on the rim:** mask at arm's length with wooden tabs pegged around the rim like a clock.
  Natural for a stick, but small text.

Recommendation: build A, with B's caption plank idea as an add-on (eyes glance at the selected
row). Pause truly pauses from the first frame; lift ~0.6 s (skippable), carve ~0.35 s. Settings
and save slots open on a flat board with plain text (readability fallback, as in Pentiment).
Quit needs two carves.

## Round 2: A2 (iteration on A)

- **No cutouts:** while playing, nothing on screen shows the mask (no eye-hole frame or vignette).
  On pause the hands reach up to the face, pull the mask down into view and turn it to show its inside.
- **Shape:** asymmetric, hand-cut. Two variants to pick from: 1, a knotted brow with a chipped right
  cheek and a grain crack; 2, long and narrow with a forked, split chin.
- **Labels:** Resume, Save, Load, Settings and Quit are scratched at odd angles and sizes (9-14 px)
  across the inside, around the knot and along the grain. Resume is always the biggest, right under the eyes.
- **Navigation:** arrows jump to the nearest word in that direction; Tab walks a fixed carve order.
  The selected word is lit like candlelight with the knife waiting at its start.

## Round 3: A2 in 3D

The same flow rebuilt as a real-time three.js mock-up in the game's PS1 look: 320x240 upscaled with
nearest filtering, clip-space vertex snapping, per-vertex (Lambert) light from a village lantern,
optional ordered dither. On pause the blocky hands reach to the face, pull the mask down and turn
its inside to you; a warm candle key light sits below the mask so the carving reads.

- **Mask:** a bent low-poly plane (concave inside) cut to shape by an alpha mask, with a darker
  outer shell behind it. Both shapes (1 and 2) are there with a toggle.
- **Words:** drawn into the inside texture as two-tone carving (pale lip, dark groove), tilted at
  most ~17 degrees. The selected word gets a flickering candle glow (a small point light plus a halo).
- **Carving:** the right hand's knife follows the selected word; a carve draws the groove over
  0.4 s and sprays small wood chips. Resume puts the mask back on; Quit needs two carves.
- Checked with a `#selftest3d` run in headless Chrome (software WebGL): picking hits every word,
  arrows and Tab reach all five, and the carve flow works on both masks.

## Round 4: mask 1, straight off the face

- **Mask 1 only** (knotted brow); the shape toggle is gone from the round-4 mock-up.
- **Take-off:** the mask starts on the face, at the centre of the view. The hands meet it there and pull
  it straight toward the player and a little down along the view axis (no arc from above the head).
  Its inside already faces the player, so it only settles a few degrees. Resume or pause runs it back
  into the centre.
- Checked as still frames at fixed points of the take-off (`#lift4-<0..1>` on the page).
