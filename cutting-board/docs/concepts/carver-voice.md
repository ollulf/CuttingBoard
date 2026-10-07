# The Carver's voice: three concepts

Babble blips (not words) for the Carver (`docs/concepts/carver.md`), like the Mask-Monger's
voice (`docs/concepts/monger-voice.md`) but darker: lower, ageless and male-ish, slightly
godly (long hall, choir and bell hints) and weird (wood creak, detuned and many-mouthed
layers). Not wired into the game; sketches to listen to and pick from.

Listening page: https://claude.ai/artifact/NCywVcHGYKGehSkpLW29eR

Rendered by `tools/audio/synth_carver_voice.gd` (a separate script from the Monger's):

    godot --headless --path cutting-board -s res://tools/audio/synth_carver_voice.gd

Files in `assets/audio/voice_concepts/carver/` (22 050 Hz mono 16-bit, peak -1.9 dBFS).
Each voice says the Monger's round 3 phrases (same syllable pitches, lengths and vowels)
so they compare directly: `*_greeting` (8 blips), `*_wise` (slow, a pause, long fall) and
`*_dialogue` (fast typed-out babble). Male vowel formants, lowered 8 % for a bigger head.

- **A. Hollow Idol** (G2, 98 Hz): a slow-vibrato low voice with a sub-octave hum, doubled
  by a whispered choir of three detuned throats an octave up, ringing in a hollow wooden
  head; long hall. The most "godly", the least weird.
- **B. Splinter Bell** (F2, 87 Hz): a bowed-wood stick-slip throat that grinds in from a
  creaky fry with a knife-on-wood scrape, plus a dark bronze bell a tritone below that
  blooms on each syllable. The darkest and most wooden.
- **C. Many Mouths** (G#2, 104 Hz): three mouths per syllable, a low throat, a ghost a
  minor ninth above on a shifted vowel and a ring-modulated whisper, a few ms apart so
  each word smears; a reversed breath swells into each phrase. The weirdest.
