# Weapon ideas: from the valley's odds and ends

Round 1, 2026-10-07. Ten weapons invented from scratch out of what a wooden village has lying
around (kitchen, loom, clock, chairs). None repeat the hammer, saw, plank, lamp, rock, the nail
guns (`nail-gun.md`) or the Workshop Armoury (`weapon-concepts.md`). The concept page with
renders is the artifact https://claude.ai/artifact/S84y8YdaD3GGvnRKQZHgSz.

Models: `tools/import/build_weapon_concepts.gd` writes
`assets/meshes/props/weapon_concept_<name>.res` (grip at the origin along +Y, like the hammer).
Photographs: `tests/visual/weapon_concept_capture.tscn -- --shots=<dir> [--plain]`. Concept only;
no ItemData or scenes yet.

1. **Marionette Cross** (bandits, Monger's thugs). Control cross with three weighted strings; flail
   that can snag a limb and yank it.
2. **Pegged Rolling Pin** (villagers). Barrel studded with pegs spins free; a hit rolls on and rakes.
3. **Chair-Leg Club** (player, dropped by chairs). Fast plain club; chairs hunt whoever carries one.
4. **Oven Peel** (baker). Shield-paddle that swats flat; scoops hearth coals and flings them.
5. **Clothes-Peg Knuckles** (player). Punches leave pegs pinched on; a full row pins an arm.
6. **Loom Shuttle** (bandits). Thrown dart trailing red yarn; two passes tie legs together.
7. **Mousetrap Mace** (bandits). Snaps onto the hand or mask it hits and stays until pried off.
8. **Pendulum Maul** (player). Clock bob on its rod; slow, heavy, keeps ticking after a swing.
9. **Back-Scratcher Rake** (elders). Its scratches strip mask paint; a blank face forgets its side.
10. **Rocker Sickle** (walking chairs). Rocking-chair runner planed keen; hooks legs, rocks foes over.

## In the game (round 2)

Five of these are real melee weapons now (`resources/items/`, `scenes/items/`): Pegged Rolling Pin (16 dmg, 2.5 kg, 200 dur) and Clothes-Peg Knuckles (9, 0.6 kg, 90) in the village wagon yard, Chair-Leg Club (19, 3.5 kg, 160) in the chair yard, Back-Scratcher Rake (11, 0.9 kg, 70) and Rocker Sickle (18, 2.0 kg, 130) in the bandit den. Plain swings only: the special moves above are not built.
