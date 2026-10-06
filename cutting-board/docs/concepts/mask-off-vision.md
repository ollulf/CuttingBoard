# Mask-off vision (concept)

Live mock-ups: https://claude.ai/artifact/WrSmnzRYCgq3quVn9ayaZf

**State:** when the player unequips the mask in the inventory, the 3D world view goes black. The inventory UI stays fully visible on top, and a "spirit world" shader plays behind it: what a puppet sees without a face.

## Shader concepts
- **A · Grain Ghosts**: dark wood grain with carved faces drifting up out of it. They blink and look at the cursor. Pure atmosphere. Screen-space `canvas_item` shader on a full-screen ColorRect (noise + TIME + mouse). Very cheap.
- **B · The Other Masks**: the masks of nearby NPCs glow, faction-coloured, where they really stand, even through walls. The world is only a faint ghost grid. A script passes up to 16 NPC mask positions and factions as a uniform array, projected with the camera matrices (or a separate visual layer with an outline shader). Cheap and informative.
- **C · The Hollow**: a breathing tunnel of tree rings with sleepy ancestor faces pressed into the wood (the Elder Tree). Screen-space polar tunnel shader. Cheap, no scene data.

## Transition
Mask off: the view closes to a vignette and goes black (0.4 s), holds, then the spirits fade in from the centre (0.8 to 2 s), with music ducked and a hum. Mask on: a fast reverse (0.3 s).

## Gameplay hooks
- B as a trade-off: you see NPCs through walls, but you have no faction (everyone treats you as a stranger) and you can't see the real world.
- A/C: hidden hints (a face that points somewhere, an ancestor who mumbles a clue).

## Recommendation
B layered over C's ring tunnel: B makes taking off the mask a real choice, and C adds the warm Elder Tree mood.
