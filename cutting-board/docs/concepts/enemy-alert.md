# Enemy alert and call for help (concept)

Result page with mock-ups: https://claude.ai/artifact/J4kY2xij3Qw9AaovcGGJui (board task `tmv0zmpzj`).

**Goal:** when a hostile NPC notices the player, it watches the player and grumbles for 5 s (the player can still slip away), then calls for help with its voice; allies in range answer with their voices and come.

## Built (round 3)
- `Alertness` (`scripts/npc/alertness.gd`) + `WatchAction` + `AlertMark` (a depth-tested `Label3D` `?`/`!`, not the carved sprite yet) on every NPC in `npc_base.tscn`; villagers set `watch_time = 0` (they still flee/fight at once).
- `Npc.call_for_help` / `answer_call` / `allies_within` (shared with `_rally_allies`); "same mask" = same `Faction.data`, which follows the worn mask.
- `Memory.remember_at`, `VoiceBark` (blip patterns from the NPC's own voice bank).
- Simplified vs the spec: no x2 for running/drawn weapon and no x0.5 crouch (only x2 under 5 m); answerers head for the spot at once and shout after their delay; the 12 s cooldown runs on the wall clock.
- Test: `tests/npc_call_for_help_check.tscn`.

## What exists today
- `Sight` (`scripts/npc/sight.gd`) looks every 0.2 s and emits `spotted(actor)` for every visible actor (view cone 140°, 15 m, plus a 2 m all-round `awareness_radius`). `Npc._ready` wires it straight into `Memory.remember`: noticing is instant and silent.
- `Memory` stores position and time per actor, forgets after 8 s. The attack action walks to `memory.last_seen_position` while the target is out of sight, so **an NPC that is told a position goes there and searches**.
- `Npc._rally_allies(attacker)` already spreads a fight: on a hit, same-faction allies within `defend_allies_radius` that see the victim (`defend_sight_window`) or `hears_allies` take up the grudge. Only villagers use it (4 m).
- Faction follows the worn mask: a player in a bandit mask is not hostile to bandits, so they never "spot" them as an enemy. The alert must key off `faction.is_hostile_to`, so disguise keeps working for free.
- Body: `Locomotion.face(position)` turns the NPC; `BodyAnimator` drops idle gestures while facing and has an `inspect` lean. Brain behaviours are scored `NpcAction`s (`wander`, `attack_target`, `flee`, `throw_at_target`).
- Voices: per-faction blips (`assets/audio/voices/bandit|villager|carver`, banks `bandit_voice.tres`, `villager_voice.tres`) with a per-NPC `Dialogue.voice_pitch`; `Sfx.play_at` plays any bank in 3D. Besides `npc_hurt` / `npc_death` there is no grunt or shout yet.

## Part 1: "spotted you" options
| | Option | Reads in play | Effort | Risk |
|---|---|---|---|---|
| A | **Carved mark overhead**: a small wooden `?` chip pops above the head while watching and fills red from the bottom; it flips to a `!` with a little bounce on the call, then falls away after ~1.5 s. Billboarded `Sprite3D`, low-res texture to match the PS1 look. | Clearest; readable at range and in a crowd. Classic stealth language. | Low | Gamey; must hide when out of view or it becomes an x-ray. |
| B | **Mask eyes flare**: the eye holes of the NPC's mask light up (ember orange while watching, hot white on the call). | Diegetic and on-theme (masks are the factions). Strong at night, weak at range or from behind. | Medium (emission on mask material per NPC) | Hard to see from the side; masks differ per model. |
| C | **Body reaction**: the NPC stops, turns its head and body to the player, leans in, reaches for its weapon. | Feels alive, no UI. | Low now that the watch gives it 5 s to play | Can be missed in a crowd. |
| D | **Voice**: grumbles in the NPC's own voice while watching, a loud call at the end. | Works off-screen: tells the player *someone* saw them behind them. | Low (blip patterns from the existing banks) | Spam when many NPCs watch at once (only one calls, see below). |

## Part 2: watch, then call (round 2; replaces the round 1 noticing delay and 0.7 s wind-up)
States: `unaware -> watching (5 s) -> calling -> fighting`, or `watching -> searching -> unaware` when the player gets away.

### Timeline
| t | Watcher | Player sees / hears |
|---|---|---|
| 0.0 s | Spots a hostile actor. Stops walking, turns to face it. | `?` mark appears. Rising **"hm?"** (2 low blips, pitch going up). |
| 0-2 s | Stands still, head tracks the player, leans in (`inspect`). | `?` fills from the bottom. |
| ~2 s | Mutters, hand goes to the weapon (draws it from the holster). | **"mm-mrr..."** (3-4 quiet blips). |
| ~4 s | One half step toward the player, `?` blinks. | Sharper **"hey!"** (2 high blips): last warning. |
| 5.0 s | **Call for help**: raises its free hand to the mask and shouts. | `?` flips to red `!`. Long loud call, ~1 s. |
| ~5.6 / 6.0 / 6.4 s | Allies answer one after another, then come. | Short answers from their positions (3D): you hear where help comes from. |
| ~6 s | The watcher attacks (existing `AttackTargetAction`). | |

### What "still in range" means
- **Range = the watcher's own Sight**: the player is in its view cone (140°, 15 m) with line of sight, or inside the 2 m all-round awareness radius. No new range number.
- The 5 s **watch meter fills only while the player is seen**: x2 when closer than 5 m, running, or holding a drawn weapon; x0.5 when crouched.
- **Sight broken** (behind a wall, out of the cone, past 15 m): the meter **pauses 1.5 s** (a quick peek back does not restart it), then **drains at half speed**. The NPC keeps facing the last seen spot and mutters "hm...".
- **Meter back to 0**: the NPC walks to the last seen spot and looks around (~4 s search), then goes back to wandering. No call. A player seen again during the search starts a new watch from 0.
- **Disguise**: only actors the NPC is hostile to start a watch, so a bandit mask still lets you walk past bandits.

### Shortcuts during the watch
- **Player comes within 3 m**: the watch ends at once; a short call and an attack in the same moment.
- **Player hits it and it survives**: instant short call, then it fights back (`_rally_allies` still spreads the grudge to allies who see it).
- **Player kills it during the watch**: no call. The watch is the stealth window: kill it in one go, break sight, or leave.
- **Two NPCs watch the same player**: only the first to fill its meter calls; the other one becomes an answerer.

### Call and answers
- **Who hears**: same-faction NPCs within **14 m** (kept from round 1), hearing not sight; each wall in between halves the reach (one ray). NPCs already fighting just learn the position.
- **Who answers**: up to **3** listeners, nearest first, each with a short voice line in its own pitch. Delay: 0.5 s + 0.4 s per answerer before it + up to 0.15 s random, so it sounds like a call and response, not a chord. Other listeners come silently (no chatter).
- **What answerers do**: turn toward the caller, get a small `!`, and `Memory.remember_at(player, caller's last seen spot)` sends them there with the existing attack/search behaviour (forgotten after 8 s if they find nothing).
- **No one in range**: the call goes unanswered; after a 1 s beat of silence the watcher attacks alone. The silence tells the player it is alone.
- **Limits kept from round 1**: one hop (answerers never call), 12 s cooldown per NPC, an NPC never answers the same call twice.

### Sounds
- **First slice, no new recordings**: a small `VoiceBark` helper plays a blip pattern from the NPC's own voice bank (count, pitch curve, gap, volume): "hm?" (2 rising), mutter (3-4 quiet), "hey!" (2 high), call (5 blips, +8 dB, pitched up, long last blip), answer (2 short blips).
- **Better later, new lines per faction** (WAVs beside the existing blips, same gibberish style): `<faction>_hm`, `<faction>_mutter` (2-3 takes), `<faction>_call` (one long shout), `<faction>_answer` (3 takes so answers differ).

Grudges stay separate: the call shares *knowledge* (faction hostility already makes allies fight), while `_rally_allies` keeps sharing *grudges* after a hit. Both use the same ally loop, extracted into one helper.

## Recommendation
**A (carved `?` mark) + C (body) + D (voice)**, all driven by the watch meter: 5 s on Sight, pause 1.5 s then drain when sight breaks, close-up or a survived hit skips straight to the call. Call 14 m with wall falloff, up to 3 staggered answers, one hop, 12 s cooldown. B as a later polish pass for night levels.

## First slice (files)
- `scripts/npc/alertness.gd` (new, beside `Sight`): watch meter per hostile actor, states `unaware / watching / calling / alerted`, signals `meter_changed`, `alerted(actor)`. Takes over the `sight.spotted -> memory.remember` wiring for hostile actors (friendly ones are still remembered at once). Pitfall: today a remembered hostile wins `AttackTargetAction` at once, so Memory must only learn of the hostile on the call.
- `scripts/npc/actions/watch_action.gd` (new `NpcAction`): scores while `watching`; stops, faces the actor, draws the weapon, plays the noises at 0 / 2 / 4 s; searches the last seen spot when the meter runs out.
- `scripts/npc/npc.gd`: `call_for_help(target)`, `_answer_call(caller, target, delay)`; exports `call_for_help_radius`, `max_answers`, `call_cooldown`; extract the ally loop from `_rally_allies` into `_allies_within(radius)`; a survived hit during the watch calls at once.
- `scripts/npc/memory.gd`: `remember_at(actor, position)`.
- `scripts/audio/voice_bark.gd`: blip patterns on a `SoundBank`.
- `scenes/vfx/alert_mark.tscn` + `scripts/vfx/alert_mark.gd`: the `?`/`!` Sprite3D driven by `meter_changed`.
- `scenes/characters/bandit.tscn`, `villager.tscn`: add the nodes and exports.
- `tests/npc_call_for_help_check.tscn`: the watcher calls after 5 s in view; 4 s out of sight cancels it; a hit skips to the call; two allies within 14 m answer in order and go to the spot, one at 20 m does not; with no one around it attacks alone.
