# Mask-Monger burn ritual (concept)

Result page with storyboard and clips: https://claude.ai/artifact/4LJpptoMTyNPUKJx9wboA9

You give the Mask-Monger a mask; he tosses it up, his lantern sets it alight, its soul
spirals down into a vial and he lobs the bottle (`scenes/items/soul_bottle.tscn`) to your
feet as a normal pickup. Goofy, not creepy: the puppet narrates. Rough animatic:
`tests/visual/monger_burn_ritual_capture.tscn` (`-- --wide` for a three-quarter view).

## Beats (about 5.8 s)

| Time | Beat | Action | Sound |
|---|---|---|---|
| 0.0–0.8 | Hand-off | Puppet arm reaches out, puppet bites the mask from your hand | clack, "Ooh, a face!" |
| 0.8–1.5 | Toss | Flicks it up spinning; head follows; lantern arm swings under | whoosh |
| 1.5–2.5 | Ignite | Lantern flame; mask face flares, swells, crumbles; embers + shavings; puppet gasps | fwoomp, crackle |
| 2.5–3.7 | Soul spiral | Smoke; amber soul spirals down; puppet chatters fast | rising whistle, babble |
| 3.7–4.6 | Bottled | Vial from the rack's bottom hook catches it; cork pop; wax seal stamped with the puppet's chin | cork pop |
| 4.6–5.8 | Set down | Lobs the bottle to your feet, small bounce; "Mind the glass!" | clink |

## Variations
- Broken mask: fizzles (grey smoke, sputter), smaller dimmer soul, "Bit of a dud."
- Rare mask: taller coloured flare, more embers, wider spiral, brighter bottle.
- Bandit mask: soul bolts sideways first; he lunges to catch it.

## Camera
No cutscene: the player keeps the view, movement is soft-locked for ~5 s and the camera
eases to keep the apex (about 2.5 m up) in frame.

## Integration plan (each ≤15 min)
1. "Give mask" interaction on the Monger, shown only when the active hand holds a mask.
2. Trade check: take the mask from the hand; normal / broken / rare from MaskData.
3. AnimationPlayer ritual on mask_monger_model (PuppetArm, LanternArm, Head, Jaw) with a method track for the beats.
4. Burn VFX scene: flare, ember/shaving/smoke GPUParticles3D, flash light.
5. Soul spiral + vial: soul_bottle frozen in the puppet hand, then unfrozen with an impulse to land as a Carryable.
6. Pause MaskMongerBody's idle chatter and sway while the ritual plays.
7. Sound cues: whoosh, crackle, cork pop, puppet babble.
