# Weapon concepts: The Workshop Armoury

Round 1, 2026-10-06. Twelve weapons taken from woodworking (sawmill, joinery, cooperage, lathe,
finishing bench, lumberyard), meant to be odd to fight with and goofy rather than gory. Each one
is described by what it does to the woody heart and to the mask (pitch draft 2). The concept
board, with animated pixel portraits in the Tallow Fair palette, a comparison grid and the full
notes per tool, is the artifact https://claude.ai/artifact/U6724Q8dggthmN2wmgYpmS. This file is
a short text copy.

Reach is measured from the eyes; the fist reaches 1.6 m today. Heart-friendly runs from 1 (heart
splinters) to 5 (heart comes out whole). Cost: S = mostly existing systems, M = one new mechanic,
L = several new mechanics.

## First picks

1. **Twelve-Foot Plank.** Nearly free: `Carryable`, `RigidBody3D` and `ImpactDamage` already do it.
2. **Mortise Chisel & Mallet.** Closes the heart loop; the two-armed `ArmAnimator` action exists.
3. **Face-Off Sanding Block.** The smallest test of "the mask is the faction", once the mask
   carries `FactionData`.

## The tools

**Twelve-Foot Plank** (lumberyard; 3.6 m, weird 3, heart 2, S). No attack button: carry it and
turning is the attack, the far end sweeping everything in the arc. Attack dips one end like a
seesaw. Splinters hearts; a head-height sweep pops a row of masks off. Needs a hold point near one
end and a grid size too long for the bag.

**Mortise Chisel & Mallet** (joinery; 0.9 m, weird 2, heart 5, M). Two hands on a limp or exposed
chest: tap, tap, tap in time, then pry. Off-beat taps split the heart. The clean harvest tool:
whole hearts carve whole faces. New: the heart item and a three-beat timing window.

**Face-Off Sanding Block** (finishing bench; 0.8 m, weird 4, heart 5, S). Hold attack on a face to
scrub; after about 1.5 s the faction paint is gone and the creature forgets its side. A half-sanded
mask reads as cracked. Works on your own face. New: a scrub loop, and the mask holding the faction.

**Hide-Glue Pot** (joinery; 1.4 m, weird 4, heart 5, M). Dab with the brush or throw the pot to
make a sticky puddle. Glue enemies to the floor or to each other, glue limbs back on. Glue a mask
on and nothing can knock it off. Reuses throwable items, `ImpactDamage` and `Destructible`; new:
the puddle and a glue joint.

**Folding Rule** (carpentry; 2.0 m, weird 3, heart 4, S). The first hit measures and pencils a line
over the heart; the next blow on the line counts as a heart hit. The marks double as the health
readout the pitch wants instead of bars. Measuring a mask reads its faction and cracks.

**Jack Plane** (joinery; 1.2 m, weird 4, heart 5, M). Push strokes take curls off the shell rather
than hit points, so the next blow lands harder. Planing a mask peels its paint in one curl. Needs
the shell layer on `Health` that the pitch describes.

**F-Clamp** (joinery; 1.0 m, weird 4, heart 5, M). Bites onto what the ray hits and cranks tighter:
pin an arm to a chest, a leg to a fence. Clamp a spare mask on a barrel for a decoy, or a second
mask over a face so both factions get suspicious. New: a pin joint on a ragdoll bone.

**Sawdust Bellows** (sawmill; 3.0 m cone, weird 3, heart 5, M). Pumping blinds creatures in the
cloud through `Sight` and makes them sneeze and drop what they hold; dust-caked masks can't be
read, so enemies hit each other. Sawdust plus lanterns is a flash fire, kept for later.

**Lathe Yo-Yo Mallet** (turning lathe; 4.0 m, weird 5, heart 3, M). Flick a turned mallet out on a
cord and it spins back; hold to roll it along the floor and trip legs. Snag a mask strap and yank
the mask back to you. New: the cord that reels the thrown head back to the hand.

**Two-Man Crosscut Saw** (sawmill; 2.4 m, weird 5, heart 4, L). You hold one handle, a hired puppet
the Sawbuddy holds the other; push on its beat and every in-time stroke hits all along the blade.
Wear a face its side hates and it lets go or switches sides. Sawing through a mask leaves half a
face. New: a partner NPC tied to an item, and a rhythm input.

**Cooper's Hoop & Driver** (cooperage; 1.5 m, weird 5, heart 5, L). Toss a hoop over a head and
drive it down: the enemy becomes a barrel with legs, to kick over and roll into its friends. The
heart stays sealed inside for the Whittlers; drive the hoop up and it covers the mask. Builds on
`barrel.tscn`; new: swapping a creature for its barrelled self.

**Whittling Knife** (whittling; 0.7 m, weird 5, heart 5, L). Every flick takes a shaving and makes
the target a size smaller, until it is a figurine for a 1x1 bag square. The heart shrinks too and
stays alive: plant the figurine to regrow it on your side. New: scaling a character and its
ragdoll at run time.

## Open questions

- A shell layer in front of the heart on `Health` unlocks the plane, the rule and the saw.
- The sanding block, bellows and clamp need the mask to carry `FactionData`.
- Glue, hoop and knife turn an enemy into something else; decide whether that counts as taking
  the heart.
