# Music concept: the wood leitmotif

First sketch, 2026-10-06. Brief: a leitmotif that makes you feel the world is wood, with
Pom Poko as the inspiration (Japanese folk festival energy, tanuki mischief, weird but
funny), then two cues built on it: the village and outside the village. The melody is
original; nothing is taken from the film.

Listen: `assets/audio/music/concepts/` (`leitmotif.ogg`, `village.ogg`, `outside.ogg`).
Result page with players and a piano roll: https://claude.ai/artifact/6wcx8pN6eGh36yWHkvhEFn

## Round 4: take E in the game

Take E is the game's music: `assets/audio/music/outside.ogg` and `combat.ogg` are copies
of `concepts/v3/e_outside.ogg` and `e_combat.ogg`, imported as loops (the concept files
stay). The `Music` autoload (`scripts/autoload/music.gd`) plays them on the Music bus,
which has no effects, so the hall and the dynamics come through as rendered.

Outside plays by default. The player's CombatTracker emits `targeted_changed` when some
NPC starts or stops going for the player, which means chasing it or throwing at it (the
rule the enemy health bar already uses). On `true` the music crossfades to Combat
(`fade_time`, 1.5 s, equal power), and Combat starts from the top of its loop. After
`combat_grace` (5 s) without any NPC going for the player, it fades back to Outside, which
resumes where it paused. Dead NPCs and NPCs whose grudge ran out drop out on their own.
The player's own blows (on a dummy, say) don't count. Checked by `tests/music_check.tscn`.
Recorded in `tests/visual/music_capture.tscn`.

## Round 3: outside and combat, no retro, weirder

Feedback on round 2: "go away from this retro feel... I always liked the outside version, so
create an outside version and a combat version. A bit weirder and subtle, no high note
melodies. Three variations." Files: `assets/audio/music/concepts/v3/<d|e|f>_<outside|combat>.ogg`,
rendered with `--set=d,e,f` (rounds 1 and 2 still render byte-identical).

- **Not retro any more**: 44.1 kHz stereo (constant-power panning per instrument), no
  downsampling, a long synthesised convolution hall (early reflections plus a darkening
  noise tail, convolved with ffmpeg `afir`) instead of the small Schroeder reverb, peaks
  hardly squeezed. New instruments with slow random drift in pitch and pressure: bowed
  wooden bars (optionally a detuned pair), a breathy bass flute, a hollow log blown like a
  didgeridoo, a paired bass marimba, big slit drums, bark scrapes, seed-pod rattles,
  groaning beams, woodpeckers and falling seeds.
- **Low and subtle**: nothing melodic above D4; measured range of the melodic voices is
  Ab1-A3 (52-220 Hz) across all six. The motif only shows up in low, broken pieces (its two
  knocks, its leap turned into a tritone, the tumble). Odd meters: 5/4, 7/8, 12/8.
- **Combat** builds from the Outside idea in the same set: a pulse of wood, a lean first
  section, a denser middle (more layers, not louder) and a thin end that leads back into
  the loop.

| Set | Character | Outside | Combat |
| --- | --- | --- | --- |
| **D, the bowed hollow** | bowed wooden drones that sag to the tritone, a quarter-tone ghost, bass flute, far slit drum | 52 BPM 5/4, 81 s | 132 BPM 5/4 (3+3+4), 64 s: muffled slit-drum pulse, Eb2 grinding against D2 in the middle |
| **E, the clockwork wood** | dry and close: hollow-log drone, woodpeckers in 3 against 5 against 7, low balafon with tritones | 84 BPM 5/4, 75 s | 150 BPM 7/8 (2+2+3), 67 s: limping slit/tongue drums, ticks, balafon ostinato |
| **F, under the floorboards** | hardly any notes: wind through a hollow trunk, groaning beams, a far heartbeat in the knock rhythm, breath tones | 60 BPM, 72 s | 96 BPM 12/8, 70 s: lub-dub heartbeat against seed shakes in fours |

Measured: outside cues -19 to -21 LUFS with 14-17 LU loudness range, combat -16 to -18 LUFS
(5-8 LU); over 85 % of the energy below 250 Hz and under 0.2 % above 2.5 kHz (round 2's
`c_outside`: 43 % / 55 % / 0.02 %); loop seams show no jump bigger than the samples around
them. `.import` files have `loop=true` and BPM/beat counts (7/8 counted in eighths, 12/8 in
dotted quarters). The mix favours the low end by design; check it on small speakers.

## Round 2: softer, woodier, three versions

Feedback on round 1: "more soft, a bit more woodiness, 3 versions". Same motif, same
generator, three alternative takes rendered side by side (round 1 kept for comparison) in
`assets/audio/music/concepts/v2/` as `<a|b|c>_<leitmotif|village|outside>.ogg`.

What changed for all three:

- **Softer**: rubber/yarn-mallet marimba, felt-muffled blocks, padded beaters (slower
  attacks of 2-4 ms instead of under 1 ms), low-passed instruments and a low-passed master,
  a darker and longer reverb, the peaks barely squeezed, slower tempos (54-96 BPM instead
  of 76-112). No taiko, belly drum, hyoshigi, shamisen, shrill shinobue or slide whistle.
  Measured: mean spectral centroid about 400-470 Hz against about 750-1130 Hz in round 1,
  energy above 2.5 kHz down from 0.2-0.9 % to under 0.1 %, while the 0.8-2.5 kHz band where
  a wooden "tok" sits stays at a similar share.
- **Woodier**: new instruments with hollow, resonant bodies: a kalimba on a wooden box, a
  balafon with its gourd (and a very soft buzz from the membrane), a wooden tongue drum,
  bamboo wind chimes, a carved wooden frog, a seed shaker, and a breathy low flute in place
  of the shinobue. Most of them go through `_wood_body`, which adds the ringing modes of a
  box or gourd under every strike.

The versions:

| | Character | Lead | Under it | The wink | Tempos (village / outside) |
| --- | --- | --- | --- | --- | --- |
| **A, lullaby** | soft mallets, rocking, warm | kalimba, soft marimba, low flute | marimba bass, kalimba picking, felt block, shaker, chimes | the slide in bar 4, a muffled bonk | 84 / 60 |
| **B, workshop** | woody percussion up front, busier | balafon, tongue drum | tongue-drum bass, slit drum, felt blocks, felt temple-block knock fills, shaker, a creak | a low-passed jaw-harp "boing" under the bonk | 96 / 72 |
| **C, forest night** | airy, sparse, lots of space | breathy low flute far off, kalimba | wind in the leaves, marimba roll pad, tongue-drum pulse, bamboo chimes | a wooden frog croaking | 72 / 54 |

Lengths: leitmotifs 26-33 s; loops 46-53 s, seamless like round 1, with `loop=true` and
the BPM and beat count in their `.import` files. Outside keeps the round-1 ideas (the fifth
sagging to a tritone, the motif at half speed and out of tune, knocks the woods answer).

## The motif

D min'yo pentatonic (D F G A C), 4 bars of 4/4. Durations are sixteenths, `/` is a slide
(or a grace note on a struck bar), `!` an accent.

```
| D5:2 D5:2 r:2 A5:4    G5:2 F5:2 G5:2 |   knock knock, a cheeky leap up, wobble
| D5:6      C5:2 A4:4   r:4            |   settle back down
| D5:2 D5:2 r:2 A5:4    C6:2 A5:2 G5:2 |   knock knock again, reaching higher
| F5:2 D5:2 C5:2 Ab4/A4:4 r:2 D4:4!    |   tumble, a wrong-footed slide Ab->A, bonk on low D
```

The idea: it opens like knuckles knocking on a wooden door (two repeated short notes), so
any two knocks in the game can quote it. The comedy is in bar 4: the slide up from the
"wrong" note Ab and the drop of more than an octave onto a low D (log drum and hyoshigi
on it). Bass roots under it: D D C A.

## Instrument palette

Everything is wood, or sounds like it, and is synthesised (no samples):

| Instrument | What it does |
| --- | --- |
| Marimba | the motif, the bass bar line, and the night drone (a soft roll) |
| Xylophone | brighter doubling; a detuned copy for the crooked night plinks |
| Shinobue (bamboo flute) | the festival lead: scoops into each note, breathy, vibrato |
| Shamisen (plucked) | offbeat fifths, with a little sawari buzz |
| Tanuki belly drum | a round "pon" under the groove; the main Pom Poko wink |
| Taiko + "ka" rim | festival drive in the village |
| Woodblock, temple blocks | offbeats; temple blocks answer the motif in call and response |
| Hyoshigi | kabuki clappers: the accelerating opening and the "kaan!" accents |
| Binzasara | wooden slat rattle, the shaker |
| Slit log drum | the bonk; far-off thuds with an echo at night |
| Mukkuri (bamboo jaw harp) | "boiyoing" at night |
| Creaking board, knocked door | sound-design accents in the night cue |

Lo-fi like the SFX: mono, 22 050 Hz, a small Schroeder reverb as a nod to the PS1 SPU.

## Cues

- **Leitmotif** (`leitmotif.ogg`, 23 s, not looping). Hyoshigi clack faster and faster
  like the start of a kabuki play, the motif bare on marimba, then on the flute with the
  whole festival, ending on the bonk.
- **Village** (`village.ogg`, 112 BPM, 32 bars, 68.6 s loop). Warm and busy, the motif
  played straight. A: groove (belly drum, bass marimba, woodblock, rattle), then the motif
  on marimba. B: flute takes it, marimba an octave down, taiko joins. C: call and response
  between marimba, temple blocks and xylophone; a slide-whistle swell, a bonk and one beat
  of stunned silence. D: everyone at once, then back to the top.
- **Outside** (`outside.ogg`, 76 BPM, 24 bars, 75.8 s loop). Night valley: sparse and a
  bit wrong, with a wink. A marimba roll drones on D with a fifth that sometimes sags to
  a tritone; a slit drum thuds far off with an echo. Someone knocks and the woods knock
  back (once with one knock too many, once with the motif on temple blocks). The flute
  plays the motif at half speed with its fifth flattened; the second half comes back in
  tune. A bamboo jaw harp boings, a board creaks, and a tanuki drums its belly far away.

Both loops are seamless: every note and the reverb/echo tails wrap from the loop end onto
its start. Their `.import` files have `loop=true` and the BPM/beat count set.

## Regenerate

```
godot --headless --path cutting-board -s res://tools/audio/synth_music.gd
godot --headless --path cutting-board -s res://tools/audio/synth_music.gd -- --set=a,b --only=village
godot --headless --path cutting-board --import
```

`--set` picks versions (`r1`, `a`-`f`; all by default), `--only` picks cues, `--mute` leaves instruments out. The
scores are text in `tools/audio/synth_music.gd` (`MOTIF` and the `_make_*` cue
functions); a bar that doesn't add up to 16 sixteenths prints a warning. Needs `ffmpeg`
on the PATH for the OGG encode (otherwise the WAVs stay in `user://music_render`).
A full run takes about 2 min 15 s (round 2 alone about 1 min 40 s). Re-rendering round 1
gives the same audio, though the OGG bytes differ (stream serial numbers).

## Next steps

- Pick a direction (A, B or C, or a mix of them), then listen and tune (tempo, mix, which
  instruments carry the motif).
- Wire them in: play `village.ogg` on the `Music` bus inside the village and crossfade
  to `outside.ogg` when the player leaves it (the two placeholder licensed tracks stay
  until then).
- Quote the motif in SFX/stingers: the two-knock rhythm for doors, the bonk for a death
  or a mask knocked off.
