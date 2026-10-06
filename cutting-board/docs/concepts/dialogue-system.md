# Dialogue system (concept)

An optional `Dialogue` node you drop onto any NPC, like `Health` or `Faction`. With it, the NPC
shows **E Talk** under the crosshair and opens a carved speech plank. Without it, nothing
changes. The first user is the Mask-Monger: the faceless player reaches him at the end of the
intro, and his talk leads into the mask trade (`docs/concepts/monger-burn-ritual.md`).

Pillars it must serve (pitch draft 1): **your face is your faction** (NPCs talk to your mask;
see "Mask-speak" in pitch section 9), **goofy and weird, never creepy**, and wooden puppets.

## 1. Goal

- One node, no NPC script changes: `Npc` > `Dialogue` (export: a dialogue file + speakers).
- It speaks through the existing interaction prompt: `Dialogue` **is a `Usable`**, so
  `get_prompt()` returns `"Talk"` and `use(by)` starts the conversation. `Interactor` and
  `interaction_prompts.gd` already handle the rest.
- Conditions and effects reach the game's systems: worn mask/faction, inventory, a global
  story state, NPC mood and grudges, and NPC-specific actions (the burn ritual).
- The logic runs without any UI, so headless tests can walk a whole tree.

## 2. Data format

| Option | Good | Bad |
|---|---|---|
| **A. Resources only** (`DialogueData` .tres with nested node/line/choice sub-resources, edited in the inspector) | Built in, typed, no parser | Nested sub-resources are painful to edit in the inspector; .tres diffs are noisy; writing 30 lines means 90 clicks |
| **B. JSON** | Built in (`JSON.parse_string`) | Unpleasant to write by hand (quotes, commas, braces); no typing; still needs a loader |
| **C. Small text format → Resource** (a `.dlg` script parsed into `DialogueData`) | Reads like a screenplay; one line per line of dialogue; clean git diffs; runtime is still a typed Resource; tests can also build `DialogueData` in code | We own a ~150-line parser |
| **D. Dialogue Manager** (nathanhoad) | Mature, the same script-like idea, has an editor and a test runner, free | An addon to keep in step with Godot versions; its own balloon/UI and state conventions to bend to our planks |
| **E. Dialogic 2** | Visual timeline editor, portraits, lots of features | Heavy; built around its own UI and character system; timelines are hard to review in git; overkill for one-person dialogue |

**Recommendation: C.** Write dialogue as small `.dlg` text files under
`resources/dialogue/`, parsed into a `DialogueData` Resource (the runtime model, and what tests
and the inspector see). Reasons: no addon, versionable and reviewable in git, fast to write for a
small team, and the conditions/effects map straight onto our own components instead of an
addon's state model. The format deliberately looks like Dialogue Manager's, so if ours outgrows
itself (localisation, a graph editor), switching to D is a port of syntax, not a rewrite.

Later, an `EditorImportPlugin` can import `.dlg` as a `DialogueData` so it shows up as a
resource in the FileSystem dock; until then `DialogueParser.load_file(path)` parses at `_ready`
and caches.

### The `.dlg` format

```
# comment
@speakers                      # tags used below; names/voices come from the Dialogue node
~ start                        # a node (label); execution starts at "start"
MONGER: Hello there.           # a line: SPEAKER: text
PUPPET: &Hullo hullo!          # "&": overlaps the previous line (both planks show)
? bare_face                    # condition on the next line or choice (the block ends at the next unindented line)
  MONGER: You've no face.
- Who are you?          -> who     # a choice, jumps to node "who"
- [has_mask] Take this mask. -> trade   # condition in [ ] hides the choice when false
- Bye.                  -> END
! set met_monger               # effect, runs when reached
! mood +1
! use MaskBurnRitual           # call use(player) on that sibling node of the NPC
-> trade                       # jump
```

Choices end a node's lines: the plank waits for a pick. A node with no choices and no `->`
ends the dialogue.

## 3. Features (MVP first)

### MVP
- **Lines** with a speaker tag, shown one at a time; E / LMB advances (first press finishes the
  carve-in, second moves on).
- **Choices** (up to 4), each with an optional condition and a jump.
- **Conditions**, a closed list (no free Godot `Expression`, keeps it testable and safe):

  | Condition | Reads |
  |---|---|
  | `bare_face` | player's `Equipment` Mask slot is empty |
  | `mask villagers` / `mask bandits` | `Faction.find_in(player).data.id` (the worn mask decides it) |
  | `has <item_id>` / `has_mask` | player `Inventory` (and hands) |
  | `flag <name>` / `not flag <name>` | `Story` flags |
  | `grudge` | `npc.has_grudge_against(player)` |
  | `mood > N` / `mood < N` | the `Dialogue` node's own `mood` int |

- **Effects**: `set <flag>`, `clear <flag>`, `mood +N/-N`, `give <item_id>`, `take <item_id>`,
  `grudge` (calls `npc.hold_grudge(player)`, ends the talk), `use <NodeName>` (calls `use(player)`
  on that NPC child, which is how the Monger's trade hooks in), `end`.
- **Greeting by face**: by convention the `start` node branches on the face first, so every NPC
  reacts to your mask: villagers greet a villager mask warmly, mutter at a bandit mask, and
  stare at a bare face ("Where's the rest of you?").

### Later
- **Portraits / speaker's face** on the plank: a small low-res render of the speaker's head
  (SubViewport) or a painted mask icon; the Monger's puppet gets its own.
- **Voice blips** per speaker (`SoundBank` per speaker tag, one blip every N characters, pitch
  jitter): see the separate voice concept task. The Monger's `monger_babble` bank is a ready
  test case for the puppet.
- **Barks**: one-liners with no UI and no lock, as a `Label3D` (billboard, pixel font) over the
  head for ~2 s, e.g. `Dialogue.bark(&"hurt")` picking a random line from a `~ bark_hurt` node.
  Also the hook for the Monger's idle chatter.
- **Interrupt when attacked**: the runner ends with reason `interrupted` when the NPC's `Health`
  takes damage or anyone attacks the player; the NPC can bark ("Rude!").
- Localisation (line ids), save/load of flags, an import plugin, a visual graph view.

## 4. Presentation

PS1 wood, readable first. A **carved plank** across the bottom of the screen, like the HUD and
pause-menu boards: dark planed wood, light carved letters (pixel font, 2x at 320x240), a small
burnt **name tag** pegged to its top-left corner. Text appears as if carved left to right
(fast typewriter with a few shavings), skippable. Two speakers talking over each other stack a
second, smaller plank above the first, slightly tilted.

Choices are **notches on a second plank**: the selected row is lit like candlelight with the
knife waiting at its start, same as pause menu A2, but no carve animation on confirm (talk must
stay quick). Pick with W/S or the mouse wheel, confirm with E/LMB, or press 1-4.

```
+--------------------------------------------------------------+
|                                                              |
|                 (world, camera eased toward                  |
|                  the Monger's head)                          |
|                         .-.                                  |
|                        (o o)  <- lantern     ___             |
|                         |=|                 (^o^) puppet     |
|      __________                                              |
|  ___[ PUPPET ]________________________________               |
| |  Ooh! Ooh! A blank! A fresh one!           |  <- overlap   |
| |____________________________________________|     plank     |
|  ___[ MASK-MONGER ]___________________________________       |
| |  Hush. ...I see you, little nobody. Even without   |       |
| |  a face to see you by.                     [E] >   |       |
| |____________________________________________________|       |
+--------------------------------------------------------------+

choices replace the hint on the main plank:
 |  > 1  Who are you?                                  |
 |    2  How can you see me?                           |
 |    3  (Hold out the mask)       <- only if has_mask |
 |    4  Goodbye.                                      |
```

- **Camera**: no cutscene. The view eases (about 0.4 s) toward the current speaker's head node
  and mouse look is damped, not removed, so the player can still glance around; the Monger's two
  speakers have two look targets (`%Head`, `%Puppet`), which makes the back-and-forth visible.
- **Movement**: locked while the plank is up (same soft-lock as the burn ritual). Leaving: a
  "Goodbye" choice, Esc/Tab (ends the talk, does not open the pause menu on the same press), or
  being pushed away beyond `talk_range` (3 m).
- **NPC**: its `Brain` pauses (as the ritual does) and its body turns to face the player.
- The hand/interact prompts hide while talking.

## 5. The Mask-Monger, first meeting

File `resources/dialogue/mask_monger.dlg`. Speakers: `MONGER` (the old carver, `%Head`) and
`PUPPET` (the hand-puppet, `%Puppet`, the babble voice). The puppet is the excited one; the
Monger is dry and tired. He "sees" without you having a face.

```
@speakers MONGER PUPPET

~ start
? grudge
  PUPPET: Nope! Shop's shut! Shop's very shut!
  -> END
? flag met_monger
  -> again
? bare_face
  -> first_bare
-> first_masked

~ first_bare
! set met_monger
PUPPET: Ooh! Ooh! A blank! A fresh one!
MONGER: &Hush.
MONGER: ...I see you, little nobody. Even without a face to see you by.
PUPPET: He sees with the lantern. I see with my mouth.
- Who are you?                  -> who
- How can you see me?           -> see
- [has_mask] (Hold out the mask) -> trade
- Goodbye.                      -> bye

~ first_masked
! set met_monger
MONGER: That face isn't yours. It fits like a borrowed boot.
PUPPET: &Borrowed! Stolen! Snatched! Which one?
- Who are you?                  -> who
- [has_mask] (Hold out a mask)  -> trade
- Goodbye.                      -> bye

~ who
MONGER: The Mask-Monger. I take faces nobody's wearing.
PUPPET: &And I do the talking!
MONGER: He does the shouting.
-> menu

~ see
MONGER: A face is a lid. Yours is off. Makes you very easy to see.
PUPPET: Draughty, too!
! mood +1
-> menu

~ menu
- [has_mask] (Hold out the mask) -> trade
- What do you do with them?     -> what
- Goodbye.                      -> bye

~ what
PUPPET: We burn 'em! Whoosh!
MONGER: &We release them. There's a little someone in every face.
MONGER: You get the someone. In a bottle. Mind the glass.
-> menu

~ trade
PUPPET: Gimme gimme gimme.
MONGER: Hold it still.
! use MaskBurnRitual
-> END

~ again
? bare_face
  PUPPET: The blank's back!
? mask bandits
  PUPPET: &Eek, a cut face! ...oh, it's only you.
MONGER: Faces to trade?
-> menu

~ bye
PUPPET: Bye bye, nobody!
MONGER: &Come back with a face. Anyone's.
```

`use MaskBurnRitual` ends the talk and hands over to the ritual, which already picks the mask
(hand first, then inventory, never the worn one) and plays the toss, burn and bottle beats.

## 6. Architecture

```
Npc (CharacterBody3D)
 ├─ Faction, Health, Inventory, Brain, ...   (unchanged)
 ├─ Dialogue          extends Usable   <- new, optional; the E "Talk"
 └─ MaskBurnRitual    extends Usable   <- today named "Usable"; renamed so E reaches Dialogue
```

| Class | Kind | Job |
|---|---|---|
| `DialogueData` | Resource | `nodes: Dictionary` (StringName → `DialogueNode`), `start := &"start"` |
| `DialogueNode` / `DialogueLine` / `DialogueChoice` | Resource | lines (speaker, text, overlap, condition, effects), choices (text, condition, effects, goto), `next` |
| `DialogueParser` | static, RefCounted | `.dlg` text → `DialogueData`; reports line numbers on errors (push_error) |
| `DialogueRunner` | RefCounted | Walks one conversation. `start()`, `advance()`, `choose(i)`, `stop(reason)`. Signals `line_started(line)`, `choices_offered(choices: Array)`, `ended(reason)`. No nodes, no UI |
| `DialogueContext` | RefCounted | Built per talk from player + NPC; `check(condition) -> bool` and `apply(effect)`; the only place that knows about Faction, Equipment, Inventory, Story, grudges |
| `Dialogue` | Node, `extends Usable` | On the NPC. Exports `dialogue_file`, `speakers: Array[DialogueSpeaker]` (tag, display name, look-at node, voice `SoundBank`, plank tint), `talk_range`, `mood`. `get_prompt()` → `"Talk"` (`""` when dead or busy); `use(by)` builds a runner. Signals `talk_started(by)`, `talk_ended(reason)`. Pauses the Brain while talking |
| `Story` | autoload | Global flags: `has(flag)`, `set_flag(flag, value := true)`, `changed` signal, `to_dict()` / `from_dict()` |
| `DialoguePlank` | Control scene in the player HUD | Bound in `interaction_prompts.gd` like the other panels; shows lines/choices; sends advance/choose back to the runner |

Flow: `Interactor.interact()` → `Usable.find_in(npc)` → `Dialogue.use(player)` → runner
`line_started` → `DialoguePlank` draws it; player presses E → `runner.advance()`; on
`ended`, the plank hides, the player's movement unlocks, the NPC's Brain resumes.

Pitfalls to handle:
- `Usable.find_in` only looks for a child named **`Usable`**. Simplest fix: make it check
  `Dialogue` first, then `Usable`. The Monger's ritual node then gets renamed `MaskBurnRitual`,
  so E talks and the trade happens through the dialogue's `use MaskBurnRitual` effect.
  (Alternative kept open: if the user wants a direct "Give mask" shortcut without talking, the
  prompt could show both, but there is only one E row today.)
- The interact press that advances a line must not also re-trigger `interact()`: while a talk is
  running the player script routes E to the plank only.
- `MaskBurnRitual._can_give` already refuses during a grudge; the dialogue checks the same so
  the choice never shows when it would fail.
- **Save/load:** there is no save system yet. `Story.to_dict()` / `from_dict()` and
  `Dialogue.mood` are the state to save; once a save system exists it calls those. Until then
  flags reset on scene reload (fine for now; the cheat menu can get a "reset story" row).

### Testing
- `tests/dialogue_runner_check.tscn` (headless): builds a `DialogueContext` with fake
  answers (bare face, has a mask, no flags), loads `mask_monger.dlg`, walks
  start → first_bare → choose "How can you see me?" → menu → trade, and asserts the speakers and
  texts in order, `met_monger` set, mood +1 and that the `use` effect was requested.
  A second pass with a bandit mask and `met_monger` set checks the `again` branch.
- `tests/dialogue_parser_check.tscn`: every `.dlg` under `resources/dialogue/` parses, every
  `->` target exists, every speaker tag is declared (catches typos when writing).
- `tests/dialogue_interrupt_check.tscn`: start talking to a villager, damage it, expect
  `ended("interrupted")` and the player unlocked.
- Plank looks: a `tests/visual/dialogue_capture.tscn` for screenshots via Movie Maker.

## 7. Build plan (each task ≤15 min, MVP first)

1. `DialogueData` / `DialogueNode` / `DialogueLine` / `DialogueChoice` resources and
   `DialogueRunner` with lines, jumps and choices (no conditions yet); runner test built in code.
2. `DialogueParser` for the `.dlg` format (speakers, nodes, lines, choices, jumps) +
   parser check.
3. `Dialogue` component (Usable subclass, "Talk" prompt), `Usable.find_in` checks `Dialogue`
   first; a test villager with a two-line `.dlg`.
4. `DialoguePlank` UI: bottom plank, name tag, carve-in text, E/LMB advance; bound in
   `interaction_prompts.gd`, prompts hidden while talking.
5. Choices on the plank: W/S, wheel, 1-4, confirm.
6. Talk lock: player movement locked, look damped and eased to the speaker, Brain paused, ends
   beyond `talk_range` or on Esc.
7. `Story` autoload + `flag` conditions and `set`/`clear` effects.
8. Face and item conditions (`bare_face`, `mask <faction>`, `has`, `has_mask`) and
   `give`/`take` effects.
9. Mood and grudge (`mood`, `grudge` conditions/effects) + interrupt on damage + its test.
10. Mask-Monger: write `mask_monger.dlg`, add `Dialogue`, rename the ritual node, `use` effect,
    speakers with two look targets; runner test walks the sample.
11. Overlapping lines (`&`): second plank, timing.

Later, one task each: voice blips, barks (`Label3D`), portraits, `.dlg` import plugin, saving
`Story` once a save system exists.

*Note:* `docs/concepts/first-five-minutes.md` (the intro ending at the Monger) was not on
`main` when this was written; the sample assumes the player arrives bare-faced, possibly
carrying a mask picked up on the way.
