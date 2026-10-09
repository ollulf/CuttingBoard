# Kick and shove

Round 2, 2026-10-09: reworked around a **targeted kick** (the player picks what to kick
and where it goes). Round 1 (tap shove / charged kick on Q) is kept below where it still
fits. Concept only, no game code. Builds on idea 4 (kick / shove) and idea 5 (momentum
damage) of `physics-combat.md` (branch `task/physics-combat-ideas`).
Result page: https://claude.ai/artifact/BJfuQQ1cX1oXpBvSUbsdV9

## Round 2: the targeted kick

### Choosing the target
- **Crosshair ray**, the same one `Interactor._get_target` casts from the camera, but
  1.8 m long (leg reach plus a step) instead of the interactor's 3 m.
- **Soft aim assist:** if the ray misses, a sphere shape-cast (radius 0.3 m) along the
  same line picks the kickable nearest the crosshair. Only the target choice snaps,
  never the camera. The round-1 pitch clamp goes: you look at what you kick.
- **Kickable:** a `RigidBody3D` under ~80 kg (props, carryables, barrels), a
  `Destructible`, a door (later), or an NPC (`HumanBody` / any `NpcBody`). Static world
  and heavier bodies are not targets: no highlight, and a hold kicks forward untargeted.
- **Highlight:** the Interactor already lays `highlight_material` over the hovered
  object's meshes (`_set_overlay`). The kick reuses that mechanism with its own warm
  orange tint, shown **only while Q is held**, so normal looking stays clean and the two
  highlights never fight. In 1.8-3 m it shows dimmed: "step closer".
- **Lock on press:** the target is chosen when the hold starts and kept while charging,
  so turning the camera aims the kick instead of switching the target. The lock drops if
  the target leaves 2.2 m or the line of sight.

### Choosing the direction
- **Props: kick at the crosshair point.** While charging, a ray from the camera finds the
  point under the crosshair (up to 20 m), and the prop is launched toward it, the way
  `Interactor._throw_direction` converges a throw on the sight line. So: lock a barrel,
  turn to the bandit, release. The barrel goes where the crosshair is.
- **Charge = power:** the hold (0.25-0.8 s) sets the impulse, 10-20 N s, as in round 1,
  plus a small upward lift (10-25 deg by charge) so a kick on flat ground travels instead
  of digging in. Speed cap ~9 m/s keeps a cup sane.
- **Trajectory line (props only):** a short dotted arc simulated from the prop's mass,
  the charge and plain gravity (no bounces), ending in a small ring. It grows with the
  charge; a full barrel shows a short arc that stops early, honest about how far it goes.
  Hidden for NPCs.
- **NPCs: kick along the view yaw** (flat); the body part decides the effect (below).

### Kicking an NPC: body parts
The body code already knows where a hit landed: `HumanBody._nearest_bone(point, ...)`
finds the struck bone, `is_head_hit(point)` the head, and `flinch(info)` pushes that bone
with the hit's impulse while the hips stay animated. So aiming at a part needs no new
body plumbing, only a choice of effect by bone:

| Aimed at | Effect | Fits today? |
|---|---|---|
| Legs (below hips) | **Trip:** 0.9 s stagger, `stagger_control` ~0, strike cancelled; full charge on a winded NPC = knockdown | Stagger yes; a real fall-and-get-up needs the knockdown of physics-combat idea 3 (`go_limp` is death only) |
| Torso / hips | **Push back:** big flat knockback via `get_knockback`, 0.6 s stagger, flinch at the spine | Yes, round 1's kick |
| Head (crouched / fallen NPC) | Damage x1.5, wears the mask via `hit_mask` | Yes, head hits already wear masks |

Ledges stay the payoff: a torso kick sends a bandit over the lookout edge, a leg kick
drops him where he stands. Until the knockdown exists, the leg kick is "long stagger,
can't step"; no fake temporary ragdoll.

### Shove: stays untargeted
A **tap** on Q stays the round-1 shove: cone, up to 3 things, no damage, no aiming. It is
the panic button (bandits crowding a doorway) and must work without lining anything up.
Only the **hold** becomes the targeted kick. Tap vs hold splits at 0.2 s, which is also
when the highlight appears.

### Controls
**Q stays** (pad R3, mouse thumb button 4). Targeting needs no extra button: the camera
is the aim, the hold is the charge, release fires.
- The hands' charge-and-release throw is the same gesture, already learned.
- RMB would take a hand away; middle mouse is awkward to hold while turning.
- Q is reachable while strafing with WASD, which is how you line up a kick.
- Cancel a held kick with **F** (stow, unused while charging) or by looking away until the
  lock drops; no stamina spent.

## First build slice (round 2): "kick the barrel at the bandit"

- `project.godot`: action `kick` (Q, mouse thumb button, joypad R3).
- `scripts/components/kick.gd` (new `Kick` node next to the `Interactor`): target pick
  (ray + sphere assist, kickable filter, lock on press), aim point under the crosshair,
  launch with charge + lift + speed cap, body-part effect on NPCs, `shove()` for taps.
- `scripts/components/interactor.gd`: make the overlay helper usable from `Kick`, so the
  target gets the second (orange) tint through the same mechanism.
- `scripts/components/impact_damage.gd`: public `arm(by, seconds)` with attacker credit,
  so the kicked barrel hurts the bandit and credits the player.
- `scripts/npc/npc.gd`: zero-damage shove/trip path (stagger, cancel strike) beside
  `_on_damaged`.
- `scenes/ui/kick_aim.gd` (new): dotted arc + landing ring, only while charging at a prop.
- `tests/kick_shove_check.tscn`: a kicked barrel lands near the crosshair point and
  damages a dummy, credited to the player; a leg kick staggers longer than a torso kick;
  a tap shoves without damage.

Later: leg mesh + hitstop, knockdown for real trips, NPCs kicking barrels at you (idea 6),
fall damage, hinged doors.

---

# Round 1 (kept for reference)

## What the code gives us today

- Bindings in `project.godot`: WASD move, Space jump, Ctrl sprint (W-W double tap latches
  it), C crouch toggle, E interact, F stow, I/Tab inventory, 1-6 hotbar, LMB/RMB the two
  hands, Shift as the grab/throw modifier on a click, Esc pause, F1 cheats, F8 retro
  screen. **Free near WASD: Q, R, G, X, Z, V; mouse thumb buttons; middle mouse.**
- No gamepad events are bound at all yet: any controller mapping is new ground.
- A plain click with an empty hand on nothing grabbable is already a punch
  (`player._use_hand` -> `_punch` -> `MeleeAttack.strike`), so the clicks are fully used.
- `MeleeAttack.strike` casts one ray, hurts one thing and adds a fixed `knockback` impulse
  to a `RigidBody3D` or `PhysicalBone3D`.
- `Health.apply_damage` ignores `amount <= 0`, so a zero-damage shove cannot ride on
  `DamageInfo` as it is: NPCs only flinch and get pushed (`NpcBody.flinch`,
  `Locomotion.push`, 0.35 s stagger) from inside `npc._on_damaged`.
- `ImpactDamage` arms only on `Carryable.released`; a kicked barrel hurts nobody.
- `HumanBody.get_knockback` flattens the push (y = 0) and divides by body mass.
- The player already has a view kick and push: `player.recoil(kick, push)`.
- No fall damage, no hinged doors (the hollow oak's door is just a gap).

## Controls: three schemes

### 1. Dedicated key, tap = shove, hold = kick (recommended)
`Q` (pad: right-stick click R3; mouse: thumb button 4 as an alternative). A tap is a quick
low shove; holding winds up a kick that grows with the hold (0.25-0.8 s) and fires on
release, the same charge pattern the hands already use for throws.
- + One key for both, no clash with hands, works whatever the hands hold.
- + Q sits next to WASD/E/F, so you can kick while strafing; R3 is the usual melee button
  on pads.
- + Charge-on-hold is already a learned gesture (throws).
- - One more key to teach (a hint on the first barrel solves it).

### 2. Context click: empty hand + Ctrl = shove, sprint into it = kick
Reuse the hands: Ctrl+click with a free hand shoves with that arm; a click while sprinting
is a running kick.
- + No new key.
- - Clicks are already overloaded (grab, wear, use, punch, Shift-throw); a fifth meaning
  will misfire. Ctrl is sprint, so "sprinting click" and "Ctrl click" collide.
- - Needs a free hand, so carrying a lantern + a hammer means no shove at all.

### 3. Movement-driven: shoulder barge + crouch-jump kick
Sprinting into a prop or NPC barges it automatically; pressing jump while crouched does a
low front kick.
- + Very physical, no new key.
- - Accidental barges in tight rooms; hard to aim; crouch-jump currently stands you up
  first, so it changes an existing rule; nobody discovers it.

**Recommendation:** scheme 1 on `Q` / R3. Keep the sprint barge from scheme 3 as a later
extra (a passive, weaker shove when sprinting into something), not as the main input.

Gamepad sketch for when pads get mapped at all: left stick move, right stick look, LT/RT
the two hands, A jump, B crouch, X interact, Y stow, **R3 kick (tap shove / hold kick)**,
L3 sprint, d-pad hotbar.

## What shove and kick do

| | Shove (tap) | Kick (hold, charged) |
|---|---|---|
| Wind-up | 0.12 s | 0.25-0.8 s hold, fires on release |
| Impulse | ~6 N s | 10-20 N s, scales with charge |
| Damage | none | 3-10 to Destructibles and characters |
| Stamina | 6 | 12-25, scales with charge |
| Cooldown | 0.4 s | 0.7 s |
| Targets | up to 3 in the cone | the first one hit |

**Hit check:** a sphere shape-cast (radius ~0.35 m) from hip height, 1.1 m forward along
the camera's yaw, pitch clamped to -35..+10 deg so looking down kicks low things and
looking up never kicks the sky. Excludes the player's own colliders with
`HumanBody.colliders_of`, as `MeleeAttack._cast` already does.

**(a) Loose props / carryables.** The impulse is fixed, so physics already makes mass
matter (a stool flies, a full barrel rolls). Cap the resulting speed (~9 m/s) so a cup
does not leave at 40 m/s. Very heavy bodies (over ~80 kg) barely move: play a dull thud
and push the player back a little with `recoil()`. A kicked object is **armed** in
`ImpactDamage` and remembers who kicked it (see below), so it hurts what it rolls into.

**(b) Doors and destructibles.** A kick damages a `Destructible` like a punch does (a crate
breaks in ~3 kicks, a fist needs more). A shove only moves it. Hinged doors do not exist
yet; when they do, a door is a `RigidBody3D` on a `HingeJoint3D`, the kick's impulse swings
it, and a locked door takes Destructible damage at its lock until it bursts open.

**(c) NPCs.** Both go through a new zero-damage-safe path, e.g. `Health.shove(info)` or
calling the NPC's push directly, since `apply_damage` drops 0 damage today:
- Shove: `Locomotion.push` with a flat knockback + the 0.35 s stagger, a small flinch, and
  `cancel_strike()` (a shove interrupts a wind-up). Breaks a grapple, makes room.
- Kick: damage + bigger push, longer stagger (0.6 s). Above a threshold (a full-charge kick
  on a winded NPC, stamina empty) it becomes the **knockdown** of physics-combat idea 3;
  until that exists, cap it at a long stagger, never a fake permanent ragdoll.
- Faction: a shove counts as aggression for grudges only if it hurts or knocks someone off
  something; a friendly NPC being pushed out of a doorway should not start a fight.

**(d) Stairs and ledges.** Knockback is flat, so a pushed NPC keeps its momentum over an
edge and falls under gravity; with `stagger_control` 0.1 it cannot walk back in time. That
is the payoff: shoving bandits off the camp lookout. This wants fall damage (none exists
yet; add it to `Health`/`Locomotion` by landing speed) or the fall is harmless. Kicking
uphill on stairs: the pitch clamp lets you aim up a few degrees. The player on a ledge
gets the same rules from NPC shoves later.

## Tie-in with impact damage

physics-combat idea 5 wants `ImpactDamage` to arm on speed for everything. The kick is the
first real user and the clean way in:
1. Make `ImpactDamage._arm()` public as `arm(by: Node, seconds := 1.5)`: armed, plus a
   "last pushed by" attacker that expires. `Carryable.released` calls it with the thrower,
   the kick calls it with the kicker.
2. `_deal_damage_to` passes that attacker in `DamageInfo`, so a barrel kicked into a bandit
   credits the player (grudges, combat tracker) instead of nobody.
3. Objects with no `impact_damage` authored deal mass x speed damage while armed. This is
   idea 5 in its narrow form (armed by hand or foot only); arming on raw speed (falling
   logs) can follow without touching the kick.

## Feel

- **Leg in first person:** a simple boot/leg mesh on the camera rig that swings up into
  the bottom of the view on the strike frame (tween, ~0.2 s), with the arms dipping. Without
  it the kick reads as a mystery force.
- **Hitstop:** 40-60 ms on a kick that lands (pause the leg tween and the target's motion
  feel; do not touch `Engine.time_scale`, it would slow NPCs and tests).
- **Camera:** reuse `player.recoil()` for a forward nudge on the strike and a small
  backward push on a heavy target.
- **Sound:** existing `swing.tres` for the whoosh, `impact_wood` / `hit_body` on contact,
  scaled by impulse; a new low "thud" bank later.
- **Stamina:** an empty pool makes the kick a weak shove rather than nothing, so the key
  never feels dead.

## First build slice (round 1, superseded above)

- `project.godot`: action `kick` (Q, mouse thumb button, joypad R3).
- `scripts/components/kick.gd` (new `Kick` node beside `MeleeAttack` on the aim): shape-cast,
  `shove()` / `kick(charge)`, impulse with speed cap, Destructible damage, NPC push, arms
  `ImpactDamage`.
- `scripts/components/impact_damage.gd`: public `arm(by, seconds)`, attacker credit, mass x
  speed damage while armed.
- `scripts/components/health.gd` (or `npc.gd`): a zero-damage shove path that flinches,
  staggers and cancels a strike.
- `scenes/characters/player.gd` + `player.tscn`: tap/hold handling, stamina, cooldown,
  `recoil()` nudge; the leg mesh is the second step.
- `tests/kick_shove_check.tscn`: shove moves a barrel without damage; a full kick rolls it
  into a dummy that takes damage credited to the player; a shove staggers an NPC.

Later: leg mesh + hitstop, sprint barge, NPCs using `Kick` on barrels (idea 6), knockdown
(idea 3), fall damage, hinged doors.
