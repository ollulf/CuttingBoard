# Mask-Monger voice: five concepts

The Mask-Monger speaks in babble, not words: one synthesised blip per syllable while her
text types out (Animal Crossing / Banjo-Kazooie style). The voice should be abstract, a
bit weird, wise, and read as female. Tone: goofy-weird wood folk, never creepy.

All five are rendered from code by `tools/audio/synth_voice_concepts.gd`:

    godot --headless --path cutting-board -s res://tools/audio/synth_voice_concepts.gd

Each concept says the same two phrases (same syllable pitches, lengths and vowels), so
the files compare the voice, not the melody:

- **greeting** (2.15 s): eight blips that lift and settle, "well-hel-lo, dear-ie-come-closer".
- **wise** (4.0 s): slower, one pause in the middle, a long falling final syllable.

## Files

All in `assets/audio/voice_concepts/` (22 050 Hz mono 16-bit, like the rest of the SFX).
Each is normalised to a −1.9 dBFS peak; RMS shows how dense it sounds.

| File | Concept | Length | RMS |
|---|---|---|---|
| `1_heartwood_alto_greeting.wav` | 1 Heartwood Alto | 2.15 s | −19.4 dBFS |
| `1_heartwood_alto_wise.wav` | 1 Heartwood Alto | 4.00 s | −20.0 dBFS |
| `2_hollow_reed_greeting.wav` | 2 Hollow Reed | 2.15 s | −16.4 dBFS |
| `2_hollow_reed_wise.wav` | 2 Hollow Reed | 4.00 s | −17.2 dBFS |
| `3_hinge_mezzo_greeting.wav` | 3 Hinge Mezzo | 2.15 s | −21.4 dBFS |
| `3_hinge_mezzo_wise.wav` | 3 Hinge Mezzo | 4.00 s | −19.7 dBFS |
| `4_whisper_hum_greeting.wav` | 4 Whisper & Hum | 2.15 s | −14.3 dBFS |
| `4_whisper_hum_wise.wav` | 4 Whisper & Hum | 4.00 s | −15.4 dBFS |
| `5_kalimba_oracle_greeting.wav` | 5 Kalimba Oracle | 2.15 s | −16.8 dBFS |
| `5_kalimba_oracle_wise.wav` | 5 Kalimba Oracle | 4.00 s | −17.9 dBFS |

Nothing in the game plays these yet; they are sketches to listen to and pick from.

## 1. Heartwood Alto

*A real throat in a hollow log: a soft, breathy alto whose vowels ring inside the mask.*

- **Made from:** a rounded glottal pulse (sawtooth softened by a half-sine) with 5 Hz
  vibrato and slow drift, low-passed at 2.6 kHz, plus 35 % breath noise, through three
  female vowel formants (a/e/i/o/u, Peterson & Barney values). A 450 Hz band-pass adds
  the boxy ring of the space behind the mask.
- **Pitch:** base A3 (220 Hz), range about G3–E4. Glides within each syllable; phrases end
  a fifth below where they peak.
- **Puppet:** same voice up an octave, no vibrato, shorter blips: she "throws" her voice.
- **Emotion:** curious = rising last syllable, more breath; amused = quick upward
  flicks and a wider vibrato; grave = drop 3 semitones, slower blips, vowels narrowed to o/u.
- **Female reads from:** female formant positions (F2 up to 2.7 kHz), alto pitch, breathiness.
- **Risk:** the most "human" of the five; can drift towards a generic mumbling-villager
  sound and lose the weirdness.

## 2. Hollow Reed

*She speaks through a wooden ocarina: pure breathy tones with a chiff of air on each word.*

- **Made from:** a near-sine (small 2nd and 3rd harmonics) with a 4.5 Hz wobble, a band
  of air noise tuned to the pitch, a faint vowel-formant colouring mixed on top, and a
  short high-passed noise "chiff" at each onset.
- **Pitch:** base A4 (440 Hz), range about G4–E5. Glides ease in (slow start, fast end),
  like breath pressure.
- **Puppet:** a smaller, higher whistle (a fourth up), quicker, with more chiff.
- **Emotion:** curious = upward glides; amused = trills (fast pitch flutter); grave =
  breath-heavy, almost pitchless air, long falls.
- **Female reads from:** pitch range and breathiness more than formants (the vowel colour
  is faint).
- **Risk:** reads as an instrument, not a person: can sound like music or a UI chime
  instead of a speaking character, and may clash with the woodwind music.

## 3. Hinge Mezzo

*A creaking door that learned to sing: bowed wood with a vocal-fry crackle on every word.*

- **Made from:** a stick-slip sawtooth (each period random in loudness and ±3.5 % in
  timing) that starts every syllable in a 38 Hz creak and rises into pitch over 70 ms,
  through fixed wooden body modes (280/520/1150/2400 Hz) plus lighter vowel formants.
- **Pitch:** base B3 (247 Hz), mezzo range about A3–F#4.
- **Puppet:** a separate, squeakier hinge: the existing `monger_babble` blips fit here.
- **Emotion:** curious = less creak, cleaner tone; amused = rapid fry-chuckle (several
  short creaks); grave = longer fry, lower, the creak lingering at phrase ends.
- **Female reads from:** mezzo pitch and vowel formants; the fry is the "old wise" part.
- **Risk:** the roughest; creaks and fry can tip into spooky haunted-house territory,
  which the tone rules out. Also the quietest (lowest RMS), needs a little more gain.

## 4. Whisper & Hum

*Two voices in one mouth: a whisper says the vowels while a low hum carries the tune.*

- **Made from:** a formant-filtered whisper (white noise through the vowel formants,
  sharp attack, short) that leads by 20 ms, under a closed-mouth hum (sine + 2nd/3rd
  harmonic, 5.5 Hz vibrato, low-passed at 900 Hz) that swells after it.
- **Pitch:** base G3 (196 Hz), contralto, range about F3–D4; the hum carries the contour.
- **Puppet:** whisper only, no hum: the puppet is the "breath", she is the "hum".
  This gives the ritual a neat split (puppet narrates, she agrees in hums).
- **Emotion:** curious = whisper louder, hum rising; amused = hum giggles in 3 short
  bumps; grave = whisper drops out, the hum alone falls slowly.
- **Female reads from:** whisper formants and the soft hum; the pitch is low, so the
  whisper does most of the work.
- **Risk:** whispering is the stock "spooky" voice; must stay warm and loud enough in the
  hum. Also the densest file (loudest RMS), easy to tire of over long dialogue.

## 5. Kalimba Oracle

*Every syllable a plucked wooden tine whose ring "wah"s from one vowel into another.*

- **Made from:** a plucked tine (fundamental, quieter octave and a fast-dying 5.4×
  inharmonic partial, like a kalimba), bent along the syllable's pitch contour, then a
  band-pass swept from the vowel's F1 to its F2 mixed in for a talking "wah", plus a tiny
  pluck click.
- **Pitch:** base C5 (523 Hz), range about Bb4–G5. Notes ring past their syllable, so
  phrases smear into little chords.
- **Puppet:** a plain music-box tine without the "wah", much faster.
- **Emotion:** curious = rising bends; amused = staccato, short decays; grave = long
  rings, low register, notes from a minor scale.
- **Female reads from:** register and the bright vowel sweep; least voice-like of the five.
- **Risk:** cute rather than wise; the ringing overlaps can get busy and it is the
  closest to existing UI sounds.

## Comparison

| | Abstract / weird | Wise | Reads female | Babble-friendly | Fits wood world | Risk |
|---|---|---|---|---|---|---|
| 1 Heartwood Alto | low | high | high | high | medium (mask ring) | too generic |
| 2 Hollow Reed | medium | medium | medium | high | high (ocarina) | sounds like music |
| 3 Hinge Mezzo | high | high | medium | medium | high (creaky wood) | spooky, rough |
| 4 Whisper & Hum | high | high | high | medium | medium | spooky whisper, dense |
| 5 Kalimba Oracle | medium | low | low | high | high (wood tine) | cute, UI-like |

## Recommendation

**Heartwood Alto as the base, with a Hinge Mezzo creak on phrase starts and ends.** The
alto gives the warm, clearly female, wise core that holds up over long dialogue, and a
short fry onset from concept 3 on the first and last syllable of a line adds the wooden
weirdness without making every blip rough. The puppet stays a second voice: it keeps
the higher, chattier existing `monger_babble` blips, so the two are easy to tell apart
during the burn ritual.

If the user prefers the weirdest option outright, **Whisper & Hum** is the strongest
single concept on paper. Worth listening to before deciding: I (the agent) could not
listen to these files, only measure them; how they actually sound is untested.
