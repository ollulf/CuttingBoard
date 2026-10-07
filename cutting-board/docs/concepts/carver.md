# The Carver

The demigod who sits on a tree stump and carves the masks everyone wears: a thin body, many
arms holding wooden carving tools and half-finished masks, and a huge spiky mask with three
eyes and a sad mouth. Based on the user's marker sketch.

Concept page (round 1): https://claude.ai/artifact/6EZkcp7XoSs3XBcPpfsjCP

## Ideas

- **A. The Rootbound Hermit** (recommended). Keeps the sketch's silhouette: he crouches on the
  stump with one long three-jointed arm reaching up and back, more arms fanning out behind
  him, and two more growing from the roots. Lore: the stump has grown into him; the
  Mask-Monger resells his rejects; the faceless player is the one face he never carved,
  which is why his mouth turns down. Mood: old, patient, sad.
- **B. The Hung Carver.** He sits upright and symmetric, with six arms hanging on strings from a
  puppeteer's crossbar in the canopy. His mask has a hinged marionette jaw. Lore: someone above
  makes him carve, maybe the Builder. Mood: uncanny, pitiable.
- **C. The Mask Orchard.** He faces front, with ten arms in a halo like a tool rack. Live
  branches rise behind him, and finished masks hang from them like fruit. His face is a slice
  of the trunk, with growth rings and tear grooves. Lore: he grows masks; the Monger picks the
  ripe ones, and the masks that never ripen become chair masks. Mood: a busy shrine.

Shared palette: warm wood, bone, deep shadow, and ember red as the single accent.
The lore links are suggestions; the Builder's identity is still open (see the pitch).

## Round 2: concept C in 3D

The user picked C. One 3D version, built by `tools/import/build_carver.gd` into
`scenes/characters/carver.tscn` (meshes `assets/meshes/characters/carver_*.res`), with a
slow code idle in `scenes/characters/carver.gd`. Not placed in any level.

- Size: stump 2 m tall; seated, he reaches about 6.5 m to the tips of his crown, with the
  branches up to about 10 m. A human is about 1.8 m.
- 16 arms in a fan round his chest, each a `%ShoulderN > %ElbowN > %WristN` chain
  (N = 0..15 from his left), holding rasps, mallets, chisels, gouges (one with an ember-hot
  tip), knives and half-carved masks.
- Around the stump: a plank stack and leaning boards, rough blanks to nearly finished masks,
  shaving heaps and curls, a chopping block with an axe, a workbench.
- Capture: `tests/visual/carver_capture.tscn` (`--shots=<dir>`, `--clip` for the idle).
