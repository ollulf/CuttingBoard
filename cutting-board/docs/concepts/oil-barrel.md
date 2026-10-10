# Oil barrel

Concept, 2026-10-10. A **wood oil barrel** (light linseed / tung / furniture oil) that
bursts into a slick, glossy golden puddle when it breaks.

> **Round 2:** re-styled from dark lamp oil to light wood oil. The barrel is a normal,
> slightly honey-toned barrel with an amber sheen; the puddle is translucent light
> amber with a warm sheen and only a faint rainbow film. Gameplay stays the same; the
> fire link still fits (linseed oil is flammable). Prototype scene: `tests/visual/oil_barrel_concept.tscn` (a kicked oil
barrel hits a post, breaks, and a puddle spreads over ~1.2 s). No game code changed.

## The barrel

- **A variant of `scenes/items/barrel.tscn`**, not a new prop: inherited scene
  `scenes/items/oil_barrel.tscn` keeping Carryable, Kickable, Destructible and
  ImpactDamage, with its own `resources/items/oil_barrel.tres` (name "Oil barrel",
  heavier: mass 55 instead of 40, since it is full).
- **Look:** the same mesh with staves slightly honey-toned (the prototype multiplies
  the wood and iron by `Color(1.08, 0.95, 0.72)` and lowers roughness, so it has a light
  oily amber sheen, not a dark soaked look), plus a small permanent **leak stain** under it when it stands in a level.
  The stain is the tell that tells it apart from a water barrel at a glance.
- **Sound ideas:** a dull slosh when picked up or kicked (reuse the wood thunk with a
  low liquid layer), and a wet splash layered on `break_wood` when it bursts
  (`Destructible.break_sound` takes any SoundBank, so the variant only swaps it).

## How breaking makes the puddle

- New component `scripts/components/spill_on_break.gd` (`SpillOnBreak`) on the variant:
  it connects to its sibling `Destructible.destroyed` and spawns a puddle scene at the
  barrel's position projected onto the ground (a short ray down, so a barrel broken on a
  slope or mid-air still lands its puddle on the floor).
- `scenes/vfx/oil_puddle.tscn` (`OilPuddle`): a flat irregular mesh, built at spawn from
  a noisy circle plus 3-5 smaller lobes (seeded per puddle, so no two match), lifted
  1 cm off the ground. It grows from 5 % to full size over ~1.2 s with an ease-out, fast
  at first like a real spill. Radius ~1.3 m for a full barrel.
- **Material:** translucent light golden amber (alpha ~0.6, more opaque at grazing
  angles), a warm sheen and a very faint rainbow film drifting slowly across it (a small spatial shader; see the prototype).
  It reads wet without screen-space reflections, which fits the PSX look. A Decal would
  follow uneven ground better; worth trying once puddles land on terrain, the flat mesh
  is fine on floors and roads.
- Why not on `Destructible` itself: keeping it a separate component lets anything spill
  later (a broken oil lamp, a tallow pot) without touching the break code.

## Gameplay of the puddle (pick one)

1. **Slippery (recommended).** Anyone who runs through slides: movement keeps its
   momentum, steering is weak, and above a speed threshold NPCs trip (reuse the 0.9 s
   trip from `Npc.kicked`). The player slides but does not fall, so it never feels
   unfair. Ties straight to the kick: **kick an oil barrel at a group of bandits**, it
   bursts at their feet, they charge you and go down. Also a trap you can set ahead of
   a fight.
2. **Slows movement.** Simple sticky ground (50 % speed). Easy to build and read, but
   it is mud with a different colour; little play beyond kiting.
3. **Slippery and flammable.** Option 1 now, and later fire (the oil lamp, the tallow /
   burn-ritual ideas in `monger-burn-ritual.md`) lights the puddle into a short ground
   fire. Strong combo, but needs a fire system first; keep the puddle's data ready
   for it (an `is_flammable` flag) and build fire separately.
4. **Pushes objects.** Props on oil slide when bumped; fun physics, but hard to read
   and adds rigid-body cost.

Recommendation: **1 now, with 3 as the planned follow-up.**

## Lifetime, merging, limits

- **Lifetime:** 60 s, then it shrinks back over 3 s and frees itself. Long enough to
  set a trap, short enough that a level does not end up paved in oil.
- **Merging:** no real merging. A new puddle overlapping an old one just refreshes the
  old one's timer and grows it a bit (up to ~2 m) instead of spawning a second mesh;
  the slip check is per area, so overlap does not stack the effect.
- **Performance:** each puddle is ~5 small meshes (~150 triangles) plus one Area3D.
  Cap at 12 live puddles; the 13th removes the oldest. No per-frame cost except the
  Area3D overlaps and the tween while growing.
- **Interaction:** `Area3D` on the puddle sets a `slippery` flag on bodies inside it
  (player controller and Npc each read it); leaving clears it after a short grace so
  you slide out of the edge.

## Open questions

- Should the player fall too (comedy, risk) or only slide (recommended)?
- Where oil barrels show up: the bandit camp (`bandit-camp-layout.md`) next to the oil
  lamp is the obvious first spot.
