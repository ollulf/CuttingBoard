# Music concept: the wood leitmotif

First sketch, 2026-10-06. Brief: a leitmotif that makes you feel the world is wood, with
Pom Poko as the inspiration (Japanese folk festival energy, tanuki mischief, weird but
funny), then two cues built on it: the village and outside the village. The melody is
original; nothing is taken from the film.

Listen: `assets/audio/music/concepts/` (`leitmotif.ogg`, `village.ogg`, `outside.ogg`).
Result page with players and a piano roll: https://claude.ai/artifact/6wcx8pN6eGh36yWHkvhEFn

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

`--set` picks versions (`r1`, `a`, `b`, `c`; all by default), `--only` picks cues. The
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
