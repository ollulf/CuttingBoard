# Kick

**Round 6, built:** **no charging.** One press kicks at once (after the 0.15 s windup)
with the old full-charge strength: 320 N s, cap 13 m/s, 22° lift (a barrel still flies a
few metres), 15 damage, 80 NPC knockback, 15 stamina (between the old tap 10 and full
charge 20). No hold/release, no charge bar. Kickable, cooldowns, whiff cost and NPC
reactions unchanged.

**Round 5, built:** **charged kick.** Hold the kick key to charge (0.7 s to full), let go
to kick; the target is still taken at the press, a tap is the old kick. A full charge
pushes 320 N s (cap 13 m/s, +12° lift; a 40 kg barrel goes ~5 m), costs 2x stamina, deals
2.5x damage (also via `ImpactDamage.arm`) and 2x NPC knockback. A thin bar under the
"kick" tag fills while charging. New component `scripts/components/kickable.gd`
(`Kickable`, `force_multiplier`): props are only kicked when they carry one; for now the
barrel, `box_large` and `box_small` in `scenes/items/` (the `barrel_1` decoration is a bare
mesh, so not kickable). NPCs need none. A static Destructible without a Kickable is no
longer a target.

**Round 4, built:** the round 3 slice is in the game: `kick` action (Q / mouse thumb /
pad R3), `scripts/components/kick.gd` on the player camera, orange target tint + a
"kick" tag by the crosshair, `ImpactDamage.arm(by, seconds, kick_damage)`,
`Npc.kicked` (legs below 0.85 m trip 0.9 s, body push 0.6 s), test
`tests/kick_check.tscn`. Deviation: a kicked prop hurts on any hit above 1 m/s (fixed 6
damage), since 25 N s moves a 40 kg barrel at only ~0.6 m/s, far below the 6.5 m/s throw
threshold. Not yet: leg mesh/animation, player recoil on heavy props, line-of-sight
recheck at the strike frame (distance only).

Round 3, 2026-10-09: simplified to **one action**. A single press of the kick key kicks
exactly one thing: whatever is under the crosshair. No hold, no charge, no separate
shove, no area push. Concept only, no game code. Builds on idea 4 (kick / shove) and
idea 5 (momentum damage) of `physics-combat.md` (branch `task/physics-combat-ideas`).
Result page: https://claude.ai/artifact/BJfuQQ1cX1oXpBvSUbsdV9
Earlier rounds are kept below as history.

## Round 3: one press, one object

### Controls
**Q** (pad R3, mouse thumb button 4 as an alternative). One press = one kick. A single
press needs no hold or release, so nothing argues for another key: Q is free, sits next
to WASD/E/F (kick while strafing), and R3 is the usual melee button on pads. No cancel
(the F-cancel goes): the kick is too short to need one.

### Which object
- **Crosshair ray** from the camera, as `Interactor._get_target` casts, but **1.8 m** (leg
  reach plus a step).
- **Small assist:** if the ray misses, a sphere shape-cast (radius **0.3 m**) along the same
  line. Only the choice snaps, never the camera.
- **Ties:** the ray's direct hit always wins. Among assist candidates: smallest angle to
  the crosshair line first, then the nearer one. Never more than one object.
- **Kickable:** a `RigidBody3D` (props, carryables, barrels), a `Destructible`, an NPC
  (`HumanBody` / any `NpcBody`), later hinged doors. Static world is not a target.
- **Hover feedback:** while a kickable is within 1.8 m, a small boot mark appears beside
  the crosshair and the object gets a warm orange overlay through the Interactor's
  `_set_overlay`. If the same object is already the Interactor's highlighted target, the
  orange tint replaces the interact tint (the E prompt stays), so one object never shows
  two overlays.
- **Press = commit:** the target is taken at the press; the hit lands on the strike frame
  0.15 s later. If it has left 2.2 m or the line of sight by then, the kick whiffs.

### Nothing in range: whiff
The leg still swings (same animation, `swing.tres` whoosh), costs **4 stamina**, and the
key is locked for the short **0.4 s** cooldown. No impulse, no hit: the key never feels
dead, but kicking the air is not free.

### Strength and direction
- **Fixed impulse, ~25 N s** for every kick; mass does the rest. The launch speed is
  capped at **9 m/s** (a 1 kg cup would get 25 m/s otherwise); a 5 kg stool leaves at
  5 m/s, a 10 kg crate rolls at 2.5 m/s, a 25 kg full barrel budges at 1 m/s, an 80 kg log
  barely rocks (dull thud + a small `player.recoil()` push back on the kicker).
- **Direction = the crosshair point:** a ray from the camera (up to 20 m) finds the point
  under the crosshair and the prop is pushed toward it, the way
  `Interactor._throw_direction` converges a throw. Props get a fixed **10 deg lift** so a
  kick on flat ground travels instead of digging in. No aim arc: one press needs none.
- **NPCs:** pushed along the view yaw (flat, `HumanBody.get_knockback`); the body part
  decides the effect (below).

### Kicking an NPC: body parts (kept from round 2)
The point under the crosshair picks the bone (`HumanBody._nearest_bone`, `is_head_hit`),
and `flinch(info)` pushes that bone. Fixed numbers now that there is no charge:

| Aimed at | Effect | Fits today? |
|---|---|---|
| Legs (below hips) | **Trip:** 0.9 s stagger, `stagger_control` ~0, strike cancelled | Stagger yes; a real fall needs the knockdown of physics-combat idea 3 |
| Torso / hips | **Push back:** flat knockback, 0.6 s stagger, flinch at the spine | Yes |
| Head (crouched / fallen NPC) | Damage x1.5, wears the mask via `hit_mask` | Yes |

Damage **6** (a crate breaks in ~3 kicks). Ledges stay the payoff: a torso kick sends a
bandit over the lookout edge.

### Impact damage (kept)
A kicked prop is **armed** with a public `ImpactDamage.arm(by, seconds := 1.5)` that also
remembers the kicker, so a barrel kicked into a bandit hurts him and credits the player
(grudges, combat tracker). `Carryable.released` uses the same call for throws.

### Numbers at a glance

| | Kick (hit) | Whiff |
|---|---|---|
| Wind-up | 0.15 s to the strike frame | same |
| Impulse | 25 N s, speed cap 9 m/s, props +10 deg lift | none |
| Damage | 6 (x1.5 head) | none |
| Stamina | 10 (empty pool: half impulse, no damage) | 4 |
| Cooldown | 0.6 s | 0.4 s |
| Targets | exactly one | none |

## First build slice (round 3): "kick the barrel at the bandit"

- `project.godot`: action `kick` (Q, mouse thumb button, joypad R3).
- `scripts/components/kick.gd` (new `Kick` node next to the `Interactor`): target pick
  (ray + sphere assist, tie rule, kickable filter), hover state for the boot mark and
  tint, press -> 0.15 s strike -> recheck target -> impulse toward the crosshair point
  with lift and speed cap, or whiff; stamina and cooldown.
- `scripts/components/interactor.gd`: make the overlay helper usable from `Kick` (orange
  tint replaces the interact tint on the same object).
- `scripts/components/impact_damage.gd`: public `arm(by, seconds)` with attacker credit.
- `scripts/npc/npc.gd`: body-part reaction (trip / push back / head) beside `_on_damaged`.
- HUD: boot mark beside the crosshair while a kick target is in range.
- `tests/kick_check.tscn`: one press kicks only the barrel under the crosshair (a second
  barrel beside it stays still); the barrel heads for the crosshair point and damages a
  dummy, credited to the player; a 1 kg prop leaves faster than a 25 kg one; a leg kick
  staggers longer than a torso kick; a press at nothing costs 4 stamina and moves nothing.

Later: leg mesh + hitstop, knockdown for real trips, NPCs kicking barrels at you (idea 6),
fall damage, hinged doors.

---

# Round 2 (history): targeted charged kick

Superseded by round 3. Hold Q locked the target under the crosshair (same ray + assist,
orange tint only while held); turning aimed; release kicked it toward the crosshair point
with charge power (0.25-0.8 s, 10-20 N s) and a dotted landing arc; a tap stayed the
untargeted cone shove (up to 3 things); F cancelled a charge. The body-part table and the
ImpactDamage tie-in carried over into round 3.

---

# Round 1 (history): tap shove / hold kick

Superseded. Kept for the code survey and the control schemes considered.

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
