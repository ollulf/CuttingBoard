# Bandit camp layout: Hollowstump

Layout proposal (round 1, nothing built yet). Visual page with a top-down map and a low-poly
sketch: https://claude.ai/artifact/MjMGjFx1p23o24ga2MSgfk

## Location
- World position about (56, 0, -68) in `test_level` (the village root is at (0, 0, -52)).
  That is about 57 m east of the well, 14 m south of the east road, with a short side trail
  branching off at x of about 50.
- It stays in the flat lowland (the terrain's hills start at 68 m). NPC sight is 15 m, so
  bandits and villagers don't notice each other.

## The tree
- A dead hollow oak, trunk ~7 m across and 9 m tall, with a snapped top. The hollow is ~5 m.
- Front door: a rotten opening facing west, toward the village, with a stolen curtain.
- Back crack: a narrow split on the east side, behind a bush.
- Den: loot chest (wood glue, rocks, spare bandit mask), a hanging lantern, a straw bed.
- Lookout: a ladder inside the trunk leads up to a plank platform on a broken limb at 6 m (NE).

## Yard
- A palisade of stolen `1x2_fence` sections in an 8.5 m ring, with the gate gap to the west.
- Fire pit with a soup pot, a stump table, and a mask rack of stolen villager masks by the door.
- A rock pile by the gate, so the guards always have something to throw.

## Bandits (5)
| Role | Where | Behaviour |
|---|---|---|
| Lookout | Limb platform | Stays put, throws rocks, sight ~25 m |
| Gate guard x2 | Both sides of the gate | Wander 2 m, defend allies |
| Cook | Fire pit | Slow wander, flees when hurt |
| Sleeper | Den bed | Short sight; wakes when hit or when allies fight |

## Ways in
- Loud: the side trail to the gate, past the guards, the lookout and the rock pile.
- Sneaky: around the south through the grass to the back crack. You reach the den and the chest.
- Masked: wear the bandit mask and walk in. You're ignored until you attack or the mask breaks.

## Build plan (each step 15 min or less)
1. Hollow tree mesh: a ring trunk with door and crack cutouts, plus collision.
2. Limb platform, inner ladder (or a plank ramp if there's no climbing yet), snapped top.
3. `bandit_camp.tscn`: palisade from fences, crates, barrels, an oil lamp; place it in `test_level`.
4. Fire pit, stump table and mask rack props.
5. Five bandits with role exports (sight, wander radius, sleeper); check the nav mesh.
6. Loot chest contents and a camp test scene.
