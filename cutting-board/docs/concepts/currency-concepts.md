# Currency concepts: Valley Purse

Rounds 1 and 2, 2026-10-06. Twelve currency ideas for a valley where every creature is made of wood. The
concept page, with pixel mock-ups in the Tallow Fair palette and a comparison table, is the
artifact https://claude.ai/artifact/BDPua9VUyUBSzgsxQF6jfZ. This file is a short text copy.

## Round 2 (stone and spirit)

Six more, three spiritual and three rocky. **Updated recommendation:** Rings stay the everyday
coin and Sap stays the barter good; add **Stonewood** as the rare top coin (a petrified Ring,
say 100 Rings = 1 Stonewood). It can't burn or rot, which makes it the one safe store of value
for wooden folk, and it extends Rings instead of adding a second system.

| Concept | Pitch | Sink | Sizes | Risk |
|---|---|---|---|---|
| **Stonewood** | Petrified heartwood: an ancestor's heart that never burns or rots | Stone masks, shrine gifts | Chip, stone ring, elder heart | Must stay rare or it flattens Rings |
| **Pebbles** | River stones: fireproof, rare in a wood valley | Hearths, foundations, cairns | Grit, pebble, cobble, hearthstone | Weight slowdown needs tuning |
| **Whetstones** | Keeps carving blades sharp | Worn down by sharpening (flint trades the same) | Sliver, palm-stone, bench-stone, grindwheel | Needs a sharpness system |
| **Spirit Knots** | A knot is a lost limb's memory; prayer beads | Offered at shrines and graves | Pin-knot, knot, eye-knot, knot-string | Cutting knots from broken limbs can read grim |
| **Ancestor Dust** | Sawdust of the Elder Tree; a pinch of grandmother | Sprinkled for blessings | Pinch, pouch, urn | Overlaps with Sap as consumable money |
| **Echo Hollows** | A whittled whistle holding one breath; value is whose voice | Blown once, then silent | Reed, whistle, horn | Not fungible: a quest item, not money |

## Round 1 recommendation

- **Primary currency: Rings.** Reads as a coin at 640x360, durable, short name ("12 rings"),
  tied to the woody heart and to what the Mask-Monger carves masks from.
- **Barter good: Sap.** It heals, so it leaves the economy on its own; shops price in Rings, the
  Whittlers and bandits also take Sap.
- **Later:** Tally Sticks as the favour layer (debts tied to a faction mask).
- Note: the inventory grid never stacks items (`inventory_entry.gd`), so any currency needs a
  purse counter on the HUD or a stack count.

## Round 1: the six

| Concept | Pitch | Sink | Sizes | Risk |
|---|---|---|---|---|
| **Rings** | Heartwood coins; more growth rings, more value | Spent on masks at the Mask-Monger | Twig-slice, branch-round, stump-round | Felling trees for money; keep to stumps and windfall |
| **Sap** | Amber resin beads that seal cracks | Spent to heal; old sap hardens into amber (savings) | Drop, bead, amber lump | Potion and cash in one; players hoard |
| **Pegs** | Dowels: spare joints you can spend | Repairs and crafting with the hammer | Tack, peg, trenail | Reads as crafting junk, not money |
| **Acorns** | Seeds are future neighbours | Planted, grow into resource trees | Seed, acorn, cone, potted sapling | Needs growth timers and persistence |
| **Matches** | Fire is the only real death for wood; whoever holds it rules | Struck to light lanterns or burn things | Match, matchbox, tinder bundle, lantern share | Fire systems are a big ask |
| **Tally Sticks** | Split notched sticks: debt you carry | Redeemed by matching halves, then snapped | Notch, stick, faction-face tally | Abstract, UI-heavy |
