# Kick animation (concept)

Result page: https://claude.ai/artifact/XsSJBW8iF2qopKAvNMjVZj

Three looks for the Q kick (`scripts/components/kick.gd`: 0.15 s windup, then the
strike), prototyped on a primitive wooden puppet kicking a barrel in
`tests/visual/kick_animation_concept.tscn` (`-- --option=a|b|c`). Each loop alternates the
first-person view and a side view.

| Option | Look | Phases (frames at 60 fps) |
|---|---|---|
| A front snap kick | knee lifts, shin snaps straight; the boot rises into the bottom of the view | chamber 6, snap 3, hold 4, recover 20 |
| B push kick (stomp) | knee to chest, flat boot thrust; camera leans back, then dips and lunges, then recoils | chamber 7, thrust 2, recoil 6, recover 21 |
| C side kick | hips turn ~85 deg, leg shoots out sideways; the view rolls ~14 deg | turn 6, extend 3, hold 5, recover 23 |

The strike frame stays on `Kick.windup` (0.15 s) in all three.

**Recommendation: B, the push kick.** It reads best in first person (the boot fills the
lower view at the strike frame), its camera dip + recoil sells the weight without a long
animation, and it matches the "one strong kick, the barrel flies" design. A is the cheap
fallback; C reads well for observers but the hip turn and roll fight first-person aim.

Building it would touch: a first-person leg rig next to the arms (player scene, an
`AnimationPlayer` track "kick_push" like the punch tracks), `kick.gd` emitting a
`kick_started` signal at the press so the leg and camera start in sync, a small camera
offset/dip on the player camera (or the existing head-bob/shake code), the NPC body
(`human_body`) gaining a kick pose for bandits who kick, and sounds: a cloth whoosh at the
chamber, a wooden thud at the strike (existing `hit_body` / prop impact), a creak on
recovery.
