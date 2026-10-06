# CuttingBoard: Pitch, draft 1

Design-focused first draft, 2026-10-06. The slides live in the Slides artifact
https://claude.ai/artifact/GFF7Y56tyG3MpGEeXJ9cX9. This file is a text copy of what the slides say.

Brief: dynamic combat where creatures use their surroundings to fight and react; explore a weird
world; masks matter (with design ideas); everything a bit goofy and weird.

---

## 1. Cover

**CuttingBoard**: a goofy folk RPG about faces, furniture and a moon that watches.
Godot 4, first person, PS1 Tallow Fair look.

## 2. The pitch

> You are the only bare face in a valley of masks. Everyone reacts to it, and everyone fights
> with whatever is lying around.

CuttingBoard is a first-person folk RPG set in a valley stuck in the hour after sunset. The
village keeps its Tallow Fair under a moon with a pupil. Bandits in antlered *cut faces* raid
from the woods. Under the well live the Whittlers, faceless carvers who made every mask in the
valley.

Fights are physical and improvised: creatures throw rocks, shove each other into fences and run
when it goes badly. A mask is who you are: wear a face and the valley treats you as whoever it
belongs to. It all looks handmade, like a puppet show. Villains sulk and fall over, and nobody
bleeds.

*The bare-face hook is a proposal of this draft, not part of the brief.*

## 3. Four pillars

| # | Brief keyword | Pillar | One line |
|---|---|---|---|
| 01 | Dynamic combat | **The room is the weapon** | Creatures and the player fight with what is lying around: rocks, barrels, hammers, walls. Everyone reacts: flinch, stagger, flee. |
| 02 | Weird world | **A valley on dream logic** | Weird, but with rules you can learn: the moon watches, faces are made things, and the well goes down. |
| 03 | Masks matter | **Your face is your faction** | What you wear decides who helps you, who runs and who attacks. Masks come off in fights. |
| 04 | Goofy and weird | **A puppet show, not a horror show** | Handmade, silly and a little sad. Villains are pompous, and fights end in slapstick. |

## 4. Creatures already fight with the room (built today)

- **Throw first, then close in.** A bandit throws every rock in its pockets, with a 0.6 s wind-up
  you can read, then switches to melee (`ThrowAtTargetAction`, then `AttackTargetAction`).
- **Hit hard, fly far.** Knockback scales with damage. Bodies flinch, stagger and ragdoll, and on
  death a mask pops off 70% of the time (`MeleeAttack.knockback_per_damage`,
  `human_body.gd` `mask_pop_chance`).
- **Everything breaks.** Thrown items wear down on impact. Walls, crates and barrels have
  durability and come apart (`Destructible`, `ImpactDamage`).
- **Brave until it isn't.** Villagers bolt on sight. Bandits break off below 25% health
  (`FleeAction.cowardice`, `flee_below_health`).
- Utility brain: each `NpcAction` scores itself and the best one runs, so a new behaviour is a new
  child node.

## 5. Next: the room fights back

| Verb | What a creature does | Built on |
|---|---|---|
| Shove | Barges you into a fence, the well or a ditch | knockback, ragdoll |
| Kick | Sends a barrel or cart rolling downhill at you | carryables, physics |
| Snuff | Knocks a lantern over and fights in the dark | lanterns are the only lights |
| Hide | Ducks behind a wagon until you run out of rocks | Sight raycasts, cover |
| Scavenge | Picks up your thrown hammer and throws it back | Carryable, throw action |
| Unmask | Goes for your face; a lost mask changes the fight | mask pop-off, factions |
| Call | Rings antler bells to bring the gang | new: a shout event |

Rule: props carry the verbs as components, creatures pick by utility. No scripted set pieces, and
about six verbs, not sixty.

## 6. Explore a valley that watches back

- **The Tallow Fair.** The village, stuck in the hour after sunset. You walk from lantern to
  lantern.
- **The valley.** Meadow and woods. Wisps gather where something died. The bandit camp is out here.
- **Under the well.** Root tunnels of the Whittlers. The mid-game descent.
- **Blind-moon nights.** The pupil closes and the Whittlers come up to trade in the square.

The moon's pupil follows you. Trees hide it, and it peeks around them.

## 7. Masks matter: your face is your faction

In the build, a mask is already how one faction tells itself from another. Make that the
player's rule too: what you wear decides how every creature reads you. A mask is a social key,
not a stat. (Lore: the Whittlers traded faces to the villagers for tallow, so every villager wears
the same pale mask. Bandits wear cut faces, stolen or badly copied masks burnt dark and bolted
with antlers.)

## 8. Three mask ideas to build first

- **A. Disguise: wear a face, be read as it.** Put on a bandit's cut face and bandits wave you
  through, until you act un-bandit: help a villager, refuse to loot. Villagers pull their kids
  inside. Suspicion is a meter, not a switch.
- **B. Unmasking: knock faces off.** A hard hit to the head pops a mask, not only on death. A
  creature without its face panics, forgets its side, or grabs the nearest mask on the ground and
  becomes that. You can steal a face mid-fight.
- **C. The face trade: carve faces with the Whittlers.** Bring back cut faces, tallow and wood.
  The Mask-Monger and the Elder carve new masks. Each mask opens a door (a faction, a place, a
  conversation) instead of adding damage.

Together they make a loop: masks change how the world reads you, fights are where masks change
hands, and the Whittlers turn what you took into new faces.

## 9. On the shelf: more mask ideas (alternatives)

- **Mask-speak.** NPCs talk to your mask, not to you. Same question, a different answer for each
  face.
- **Masks crack.** Masks have durability. A cracked one half-works, and bandits squint at you.
- **Masks on things.** Hang a mask on a barrel, a scarecrow or a goat, and NPCs treat it as a
  person. Decoys.
- **Borrowed habits.** A caste's mask lends its quirk. Backwards Jack's lets you run backwards,
  fast.
- **Your bare face.** The weirdest thing in the valley. Kids stare, and the Whittlers want to fix
  it.
- **The moon's mask.** Blind-moon nights are the moon wearing a mask. Someone carved it.

**First-person problem: you never see your own mask.** Show it anyway: hands lift it on when you
equip it, it rims the screen edge, it shows in your shadow and in puddles, and NPCs comment on it.

## 10. Goofy and weird, never creepy

- **Handmade puppets.** Wax, cloth, carved wood and tin. No flesh, no teeth, no gore.
- **Villains are pompous,** greedy or sneaky. They flee, sulk and fall over.
- **Pain is slapstick.** Big pixel damage numbers, a fun-house mirror wobble on hits, masks
  flying off.
- **One odd part each:** six arms, a face on the back of the head. It has to read as a silhouette.
- **Light says intent.** Amber means trade, flame means bandit, moon-yellow means strange.

The Whittlers: six castes, each wearing the mask somewhere else (Chiseller, Totem Warden,
Crook-Neck Elder, Backwards Jack, Mask-Monger, Sprig).

## 11. The core loop

1. **Explore.** Walk the dark from lantern to lantern. Find a place, a person, a face.
2. **Get read.** Creatures react to the face you wear: trade, ignore, flee or attack.
3. **Improvise.** Fight with the room: throw, shove, break, run. So do they.
4. **Take faces.** Masks pop off. Pick them up, or leave them for the Whittlers.
5. **Carve.** Trade with the Whittlers for new masks, and new doors.

Back to 1: with a new face, the same valley reads you differently. Closed doors open and friends
turn wary. Meta layer (open): the bare-face mystery and the moon.

## 12. Art and audio: the Tallow Fair

- **Look (built).** PS1 pipeline: a low retro resolution, ordered dither, a 12-colour grade and
  purple fog. Lantern posts are the only real lights, and a huge moon has a pupil.
  Palette: `#07050A #0D0812 #1A1020 #2A1830 #3A2440 #4A2C4A #2B1D10 #5A3A1C #A8642A #F0A838
  #E8D48A #D9C9A0`.
- **To push it goofier.** Stepped 12 fps creature animation, painted fair stripes, brighter warm
  pools around stalls.
- **Audio (proposal, nothing built).** Wooden knocks and creaks for hits, an out-of-tune
  fairground organ, muffled gibberish voices behind masks, a tallow hiss when you are hurt.

## 13. What exists today, and what comes next

| Built | Next (proposed) |
|---|---|
| First person with two hands, hotbar and inventory | A mask slot that changes how factions read you |
| Carry, charged throws, melee with knockback | Head hits that knock masks off, and picking them up |
| Ragdoll flinch, stagger and death, with masks popping off | Three new verbs: shove, scavenge, snuff the lantern |
| NPC utility brain: wander, flee, attack, throw | The first Whittler (Mask-Monger) and carving |
| Factions: player, villagers, bandits | The well descent as the first new place |
| Breakable props and walls | A first audio pass |
| Village and valley terrain, Tallow Fair look | |
| Health HUD, enemy bar, hurt warp | |

## 14–15. Feedback on the brief

**"Dynamic combat where creatures use their surroundings to fight and react"**
- Works: the most distinctive point, and partly real already (throw then melee, knockback,
  ragdolls, breakables).
- Risk: "dynamic" is a buzzword; name the verbs. Systemic AI is the biggest scope risk: every prop
  times every creature. At 640×360 in the dark a thrown rock is hard to see, and first person
  hides the slapstick that happens beside you.
- Try: "Every fight is improvised: creatures grab, throw, shove and break what's around them, and
  so do you."

**"Explore a weird world"**
- Works: the valley already has a strong image: the moon with a pupil, the endless dusk, the well.
- Risk: every game says this. Weird without rules feels random. Today the world is one village and
  one valley, and there is no reward for exploring yet.
- Try: "A valley with dream logic you can learn: faces are made things, the moon watches, the well
  goes down."

**"Masks matter"**
- Works: the best hook, already in the lore (the Whittlers' face trade) and in the code (faction
  masks that pop off).
- Risk: it stays cosmetic unless masks change AI and dialogue. In first person you never see your
  own mask. Majora's Mask is the comparison everyone will make.
- Try: "Your face is your faction: wear one and the valley treats you as whoever it belongs to."

**"Everything a bit goofy and weird"**
- Works: it fits the creature rules (pompous villains, puppets, no gore), and ragdolls are funny
  on their own.
- Risk: the current look reads creepy, not goofy. The art pitch called it "folk horror, warm
  dread". Goofy needs timing in sound, animation and writing, and none of that exists yet.
- Try: "A puppet show at night: handmade, silly, a little uncanny, never gory." Pick a ratio,
  e.g. 70% goofy, 30% uncanny.

## 16. What the pitch doesn't say yet

- **Who you are and why you're here.** No player fantasy or goal. The bare-face stranger is one
  answer.
- **What grows.** No progression. Suggestion: masks and favours, not numbers.
- **What makes it an RPG.** Quests, dialogue, stats and choices aren't mentioned.
- **What losing means.** Death, knock-out, or losing your face?

| Comparable | We share | We differ |
|---|---|---|
| Majora's Mask | Masks change who you are | Masks are social, worn and lost in fights |
| Exanima, Dark Messiah | Physical melee, kicks, props | Goofy, and the creatures improvise too |
| Zelda: Tears of the Kingdom | Systemic props | Small, dense and social |
| Kenshi | Factions, a cruel open world | Factions you can read by their faces |
| Mad God, Hylics | Handmade, weird | Playful, never grim |

## 17. Open questions

1. Is the player the bare-faced stranger, or a villager who lost their face?
2. Stay in first person, or use a third-person camera that shows the slapstick and your own mask?
3. One dense valley, or several regions?
4. Do creatures die, or get knocked out and unmasked? The second is goofier and keeps the cast
   alive.
5. Do masks have stats at all, or only social effects?
6. Does the sun ever come back?
7. How many creature verbs for a first playable slice: three, or six?
8. Does the working title stay? CuttingBoard says kitchen, not masks.
