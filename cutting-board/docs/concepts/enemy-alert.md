# Enemy alert and call for help (concept)

Result page with mock-ups: see the task card (board task `tmv0zmpzj`).

**Goal:** when a hostile NPC notices the player, the player sees and hears it happen, and the NPC then shouts for help so same-faction NPCs within a radius learn where the player is.

## What exists today
- `Sight` (`scripts/npc/sight.gd`) looks every 0.2 s and emits `spotted(actor)` for every visible actor (view cone 140°, 15 m, plus a 2 m all-round `awareness_radius`). `Npc._ready` wires it straight into `Memory.remember`: noticing is instant and silent.
- `Memory` stores position and time per actor, forgets after 8 s. The attack action walks to `memory.last_seen_position` while the target is out of sight, so **an NPC that is told a position goes there and searches**.
- `Npc._rally_allies(attacker)` already spreads a fight: on a hit, same-faction allies within `defend_allies_radius` that see the victim (`defend_sight_window`) or `hears_allies` take up the grudge. Only villagers use it (4 m).
- Faction follows the worn mask: a player in a bandit mask is not hostile to bandits, so they never "spot" them as an enemy. The alert must key off `faction.is_hostile_to`, so disguise keeps working for free.
- Voices: `Dialogue.voice` + `voice_pitch` play `SoundBank` blips (`bandit_voice.tres`, `villager_voice.tres`), and `Sfx.play_at` plays any bank in 3D.

## Part 1: "spotted you" options
| | Option | Reads in play | Effort | Risk |
|---|---|---|---|---|
| A | **Carved mark overhead**: a small wooden `?` chip pops above the head while suspicious and fills red from the bottom; it flips to a `!` with a little bounce when alerted, then falls away after ~1.5 s. Billboarded `Sprite3D`, low-res texture to match the PS1 look. | Clearest; readable at range and in a crowd. Classic stealth language. | Low | Gamey; must hide when out of view or it becomes an x-ray. |
| B | **Mask eyes flare**: the eye holes of the NPC's mask light up (ember orange while suspicious, hot white on alert). | Diegetic and on-theme (masks are the factions). Strong at night, weak at range or from behind. | Medium (emission on mask material per NPC) | Hard to see from the side; masks differ per model. |
| C | **Body reaction**: head snaps to the player, short startle hop, then the NPC points the weapon hand at the player before charging. | Feels alive, no UI. | Medium (BodyAnimator look-at + one arm pose) | Can be missed in a fight; needs ~0.5 s that reads as a delay. |
| D | **Bark**: a short, loud gibberish shout in the NPC's own voice ("HUP!"), from the voice bank pitched up, plus a rising "hm?" while suspicious. | Works off-screen: tells the player *someone* saw them behind them. | Low (a new `SoundBank` reusing the blips) | Spam when many NPCs spot at once (needs a cooldown). |

**Noticing delay (applies to all):** instead of instant awareness, a hostile actor in view builds *suspicion* from 0 to 1. Faster when close, in the centre of the cone, or when the player runs; slower when crouched or at the edge of view. Inside `awareness_radius` or when hit it jumps straight to 1. Suspicion decays when sight is lost. This gives the player a beat to duck out of view, and is what the `?` fill shows.

## Part 2: call for help
1. **Alerted** (suspicion reaches 1): bark + `!` + head snap. The NPC remembers the player as today.
2. **Wind-up, 0.7 s**: the NPC raises the free hand to its mask and shouts. The shout lands at the end, so **killing or staggering it during the wind-up cancels the call** (a hit already runs `cancel_strike`; the shout cancels the same way).
3. **Shout**: every same-faction NPC within `call_for_help_radius` (proposed **14 m** for bandits) hears it. Hearing, not sight: no line-of-sight check, but each wall between halves the reach (one ray). Each listener gets `Memory.remember_at(player, caller's last seen position)`, so the existing attack/search behaviour walks it to that spot, and it forgets after 8 s if it finds nothing. Listeners get a smaller `?` that snaps straight to `!` and turn toward the caller.
4. **Chain:** off by default (one hop), so one camp alerts itself but not the whole map. A `relays_alerts` export lets a sentry/drummer re-shout once. Every alert carries the original caller, and an NPC never relays the same alert twice.
5. **Cooldown:** 12 s per NPC between shouts; a listener that was just alerted does not shout itself for that long either.

Grudges stay separate: the shout shares *knowledge* (faction hostility already makes allies fight), while `_rally_allies` keeps sharing *grudges* after a hit. Both use the same ally loop, extracted into one helper.

## Recommendation
**A + D + noticing delay, then C's head snap** (cheap with the existing look-at). B as a later polish pass for night levels. Call for help as above: 14 m, hearing with wall falloff, one hop, interruptible 0.7 s wind-up.

## First slice (files)
- `scripts/npc/alertness.gd` (new `Alertness` node beside `Sight`): suspicion per actor, states `unaware / suspicious / alerted`, signals `suspicion_changed`, `alerted(actor)`; takes over the `sight.spotted -> memory.remember` wiring for hostile actors (friendly ones are still remembered at once).
- `scripts/npc/npc.gd`: `call_for_help(target)` with the wind-up timer and `call_for_help_radius` / `relays_alerts` / `call_cooldown` exports; extract the ally loop from `_rally_allies` into `_allies_within(radius)`; cancel the wind-up in `_on_damaged`.
- `scripts/npc/memory.gd`: `remember_at(actor, position)`.
- `scenes/vfx/alert_mark.tscn` + `scripts/vfx/alert_mark.gd`: the `?`/`!` Sprite3D following the eyes, driven by `suspicion_changed`.
- `resources/audio/bandit_shout.tres`: bandit blips, louder, pitched up.
- `scenes/characters/bandit.tscn`: add the nodes and exports.
- `tests/npc_call_for_help_check.tscn`: a bandit spots the player, a second bandit 10 m away behind it learns the position, a third at 20 m does not; a hit during the wind-up cancels the call.
