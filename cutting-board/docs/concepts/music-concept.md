# Music concept: the wood leitmotif

First sketch, 2026-10-06. Brief: a leitmotif that makes you feel the world is wood, with
Pom Poko as the inspiration (Japanese folk festival energy, tanuki mischief, weird but
funny), then two cues built on it: the village and outside the village. The melody is
original; nothing is taken from the film.

Listen: `assets/audio/music/concepts/` (`leitmotif.ogg`, `village.ogg`, `outside.ogg`).
Result page with players and a piano roll: https://claude.ai/artifact/6wcx8pN6eGh36yWHkvhEFn

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
godot --headless --path cutting-board -s res://tools/audio/synth_music.gd -- --only=village
godot --headless --path cutting-board --import
```

The scores are text in `tools/audio/synth_music.gd` (`MOTIF` and the `_make_*` cue
functions); a bar that doesn't add up to 16 sixteenths prints a warning. Needs `ffmpeg`
on the PATH for the OGG encode (otherwise the WAVs stay in `user://music_render`).
A full run takes about 35 s.

## Next steps

- Listen and tune (tempo, mix, which instruments carry the motif).
- Wire them in: play `village.ogg` on the `Music` bus inside the village and crossfade
  to `outside.ogg` when the player leaves it (the two placeholder licensed tracks stay
  until then).
- Quote the motif in SFX/stingers: the two-knock rhythm for doors, the bonk for a death
  or a mask knocked off.
