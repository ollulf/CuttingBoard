# CuttingBoard: Pitch, draft 2

Four-slide pitch, 2026-10-06. The slides live in the Slides artifact
https://claude.ai/artifact/GFF7Y56tyG3MpGEeXJ9cX9 (draft 1 was replaced there; its text copy is
`pitch-draft-1.md`). This file is a text copy of what the slides and their notes say.

Brief (round 2): condense to four slides. Every creature is wood, the masks are the factions, and
every enemy has a woody heart that is its life and also a resource.

---

## 1. Every creature is wood

Villagers, bandits, the Whittlers, the goats: everything that walks in the valley was carved or
grew. Nobody is flesh, so nobody bleeds.

- **Look.** Flat carved planes are what PS1 low-poly already does. The human body stays; it gets
  grain, pegged joints and tool marks. Lantern light pools on varnish.
- **Feel.** Hits knock and clack. Chips and splinters fly instead of blood. A ragdoll is a puppet
  with its strings cut.
- **Cast.** Villagers: pale lime-washed pine. Bandits: charred oak, their antlers are branches.
  Whittlers carve themselves. Animals grew from roots.
- **Tone.** Wood makes violence goofy: no gore, just dents and lost limbs that get glued back. And
  the title finally fits: a cutting board.

Footer: wood + tallow lanterns = everything can burn. Use it, sparingly.

## 2. The mask is the faction

Bodies are just wood. The face you wear is the only thing that says whose side you are on.

- **Swap: wear a face, be read as it.** Put on a bandit face and bandits wave you through, until
  you act un-bandit. Suspicion is a meter, not a switch.
- **Break: knock faces off.** A head hit pops the mask. A blank creature forgets its side: it
  panics, or grabs the nearest mask and joins that team.
- **Decoy: masks on things.** Hang a villager face on a barrel or a goat and bandits attack it. A
  cracked mask only half works.

Notes: in the build the `Faction` component and the mask are separate; the change is to let the
mask carry the `FactionData`, so knocking it off really changes sides. Masks already pop off on
death (`mask_pop_chance` 0.7). First person: show your own mask through the hands putting it on, a
rim at the screen edge, your shadow and NPC remarks.

## 3. The woody heart

**It is their life.**
- A knot of heartwood glows in every chest. Its cracks are the health bar: no bar over heads, just
  a heart that splits and dims.
- Body hits chip the shell. Expose the heart and hits land double. When it splits, the puppet
  drops.
- Creatures guard it: they turn their chest away, cover it, and run when it flickers.

**It is your resource.**
- **Carve.** A bandit heart carves a bandit face. Whose heart decides which faction's mask you get.
- **Grow.** Graft one into your own: a new ring, more life.
- **Trade.** Hearts are what the Whittlers pay in, and what they want.
- **Plant.** Bury one and it regrows a creature, on your side.

**The twist:** how you win decides what you get. A clean blow keeps the heart whole; a barrel to
the chest leaves splinters.

## 4. How it plays

1. **Fight.** With the room: throw, shove, break. So do they.
2. **Take hearts.** Pry them out. Whole or in splinters.
3. **Carve.** The Whittlers turn hearts into faces.
4. **Swap sides.** New face, new friends, new enemies.
5. **Explore.** Doors that were shut now open.

- **Combat with the surroundings.** Creatures throw, shove and hide to protect their hearts. Props
  are the weapons, and how hard you hit decides your loot.
- **Goofy and weird.** A puppet show at night: pompous wooden bandits, a moon with a pupil, goats
  that grew from roots. Nobody bleeds.

Footer: open: is taking hearts killing? Who are you without a mask?

### Candid notes (speaker notes of slide 4)

1. Hearts as both life and currency make every fight a harvest. That pushes toward grinding and
   toward killing everyone, villagers included. Decide early whether a creature can lose its heart
   and live (knocked out, regrown from a planted heart) and whether villager hearts are taboo;
   otherwise the goofy tone turns grim fast.
2. If the mask is the faction, the player needs a clear default: an uncarved, blank face that
   nobody trusts is a good start, and it gives the story a question (who carved you?).
3. Code: the faction and the mask are separate on a creature today; the mask would carry the
   faction, and `Health` would read as heart integrity. Both are contained changes.
4. Wood plus lantern fire is a tempting system; keep it out of the first slice.
