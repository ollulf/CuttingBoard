extends "res://tools/audio/synth_base.gd"

## Renders the five Mask-Monger voice concepts (docs/concepts/monger-voice.md) as WAVs in
## assets/audio/voice_concepts/: per concept a short greeting of babble blips and a
## slower, falling "wise" line. Concept sketches only, not wired into any SoundBank:
##
##   godot --headless --path cutting-board -s res://tools/audio/synth_voice_concepts.gd
##
## Pass `-- godly` to render only the round 3 "godly" voices into voice_concepts/godly/;
## each also gets a fast "dialogue" sample to test how the reverb holds up at speed.
##
## Pass `-- monger` to render the chosen voice (C, Breath of the Grove) into
## assets/audio/voices/mask_monger/: its three phrases plus single syllable blips for a
## dialogue system (bank: resources/audio/monger_voice.tres).
##
## Every concept speaks the same two phrases (same syllable pitches, lengths and vowels),
## so the files compare the voice itself, not the melody. Same lo-fi format and filter
## approach as synth_sfx.gd; prints peak and RMS level of each file.

const ROOT := "res://assets/audio/voice_concepts/"

## Female vowel formants (F1, F2, F3 in Hz), roughly from Peterson & Barney.
const A := [850.0, 1220.0, 2810.0]
const E := [560.0, 2300.0, 2950.0]
const I := [330.0, 2700.0, 3300.0]
const O := [560.0, 1000.0, 2800.0]
const U := [370.0, 950.0, 2700.0]

## A syllable: [semitones at start, semitones at end, length s, pause after s, vowel].
## The greeting lifts and then settles; the wise line is slow, pauses once, and falls.
var greeting := [
	[0, 2, 0.13, 0.03, E], [4, 3, 0.11, 0.03, A], [5, 5, 0.10, 0.03, O], [7, 4, 0.22, 0.14, A],
	[3, 2, 0.11, 0.03, I], [2, 0, 0.12, 0.03, E], [0, -2, 0.13, 0.04, O], [-3, -5, 0.40, 0.0, U],
]
var wise := [
	[-2, 0, 0.22, 0.07, O], [0, 0, 0.18, 0.07, A], [3, 2, 0.26, 0.07, E], [2, 0, 0.32, 0.38, O],
	[0, 1, 0.20, 0.07, I], [-1, -2, 0.22, 0.07, A], [-3, -3, 0.22, 0.08, E], [-5, -7, 0.75, 0.0, U],
]


## Fast dialogue babble for round 3: two quick runs of short syllables, as typed-out text.
var dialogue := [
	[0, 1, 0.07, 0.02, E], [2, 2, 0.06, 0.02, A], [3, 2, 0.07, 0.02, O], [1, 1, 0.06, 0.02, I],
	[2, 3, 0.07, 0.02, A], [4, 4, 0.06, 0.02, E], [3, 2, 0.07, 0.02, U], [2, 1, 0.06, 0.02, O],
	[0, 0, 0.08, 0.02, A], [-1, -2, 0.12, 0.22, E],
	[2, 3, 0.07, 0.02, I], [4, 3, 0.06, 0.02, A], [3, 3, 0.07, 0.02, O], [2, 2, 0.06, 0.02, E],
	[1, 2, 0.07, 0.02, A], [3, 2, 0.06, 0.02, U], [1, 0, 0.07, 0.02, O], [0, -1, 0.06, 0.02, I],
	[-2, -2, 0.08, 0.02, E], [-3, -5, 0.24, 0.0, A],
]


func _init() -> void:
	if "monger" in OS.get_cmdline_user_args():
		_render_monger()
		quit()
		return
	if "godly" in OS.get_cmdline_user_args():
		_render_godly()
		quit()
		return
	var concepts := {
		"1_heartwood_alto": [220.0, _syl_alto],
		"2_hollow_reed": [440.0, _syl_reed],
		"3_hinge_mezzo": [247.0, _syl_hinge],
		"4_whisper_hum": [196.0, _syl_whisper_hum],
		"5_kalimba_oracle": [523.0, _syl_kalimba],
	}
	for concept in concepts:
		var base: float = concepts[concept][0]
		var syl: Callable = concepts[concept][1]
		rng.seed = hash(concept)
		_save(concept + "_greeting", _phrase(greeting, base, syl, 1.0), 0.8)
		_save(concept + "_wise", _phrase(wise, base, syl, 1.1), 0.8)
	quit()


## Lays the syllables of `phrase` end to end, each rendered by `syl`.
func _phrase(phrase: Array, base: float, syl: Callable, stretch: float) -> PackedFloat32Array:
	var total := 0.5
	for s in phrase:
		total += (s[2] + s[3]) * stretch
	var out := _silence(total)
	var at := 0
	for s in phrase:
		var f0a := base * pow(2.0, s[0] / 12.0)
		var f0b := base * pow(2.0, s[1] / 12.0)
		_mix(out, syl.call(s[2] * stretch, f0a, f0b, s[4]), at, 1.0)
		at += _seconds((s[2] + s[3]) * stretch)
	return out


# --- The five voices ----------------------------------------------------------------------


## 1. Heartwood Alto: a breathy, soft glottal source with a slow vibrato through female
## vowel formants, plus a hollow 450 Hz ring for the wooden mask cavity.
func _syl_alto(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var source := _glottal(length + 0.12, f0a, f0b, 5.0, 0.015, 0.003)
	source = _lowpass(source, 2600.0, 0.7)
	var breath := _noise(length + 0.12)
	for i in source.size():
		source[i] += breath[i] * 0.35
	var voiced := _formants(source, vowel, [1.0, 0.55, 0.25], 8.0)
	_mix(voiced, _bandpass(source, 450.0, 4.0), 0, 0.5)
	return _shape(voiced, 0.025, length * 0.9)


## 2. Hollow Reed: an ocarina breath, a near-sine at the pitch with a chiff of air on the
## onset; a faint vowel filter lets it "say" things.
func _syl_reed(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var n := _seconds(length + 0.1)
	var out := _silence_samples(n)
	var phase := 0.0
	var wobble := 0.0
	for i in n:
		var t := clampf(float(i) / _seconds(length), 0.0, 1.0)
		wobble = clampf(wobble + rng.randf_range(-0.002, 0.002), -0.01, 0.01)
		var f0 := lerpf(f0a, f0b, t * t) * (1.0 + wobble + 0.008 * sin(TAU * 4.5 * i / sample_rate))
		phase += f0 / sample_rate
		out[i] = sin(TAU * phase) + 0.18 * sin(TAU * 2.0 * phase) + 0.06 * sin(TAU * 3.0 * phase)
	var air := _bandpass(_noise(length + 0.1), (f0a + f0b) * 0.5, 3.0)
	_mix(out, air, 0, 1.6)
	var coloured := _formants(out, vowel, [1.0, 0.6, 0.2], 5.0)
	_mix(out, coloured, 0, 1.2)
	out = _shape(out, 0.04, length * 0.8)
	var chiff := _shape(_highpass(_noise(0.05), 2500.0, 0.8), 0.003, 0.04)
	_mix(out, chiff, 0, 0.35)
	return out


## 3. Hinge Mezzo: a bowed-wood stick-slip source (each period a little louder or softer,
## a little early or late) that starts in a creaky fry, through fixed wooden body modes
## and lighter vowel formants.
func _syl_hinge(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var n := _seconds(length + 0.1)
	var source := _silence_samples(n)
	var phase := 0.0
	var amp := 1.0
	var jitter := 0.0
	var fry := 0.07
	for i in n:
		var t := clampf(float(i) / _seconds(length), 0.0, 1.0)
		var sec := float(i) / sample_rate
		var f0 := lerpf(f0a, f0b, t)
		if sec < fry:
			f0 = lerpf(38.0, f0, pow(sec / fry, 3.0))
		phase += f0 * (1.0 + jitter) / sample_rate
		if phase >= 1.0:
			phase -= 1.0
			amp = rng.randf_range(0.55, 1.0)
			jitter = rng.randf_range(-0.035, 0.035)
		source[i] = (2.0 * phase - 1.0) * amp
	var body := _formants(source, [280.0, 520.0, 1150.0, 2400.0], [0.8, 1.0, 0.6, 0.3], 10.0)
	_mix(body, _formants(source, vowel, [0.7, 0.4, 0.15], 9.0), 0, 1.0)
	return _shape(body, 0.02, length * 0.85)


## 4. Whisper & Hum: a closed-mouth hum carries the pitch while a formant-filtered whisper
## speaks the vowel just ahead of it, like two voices sharing one mouth.
func _syl_whisper_hum(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var n := _seconds(length + 0.15)
	var hum := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := clampf(float(i) / _seconds(length), 0.0, 1.0)
		phase += lerpf(f0a, f0b, t) * (1.0 + 0.01 * sin(TAU * 5.5 * i / sample_rate)) / sample_rate
		hum[i] = sin(TAU * phase) + 0.35 * sin(TAU * 2.0 * phase) + 0.12 * sin(TAU * 3.0 * phase)
	hum = _shape(_lowpass(hum, 900.0, 0.7), 0.05, length)
	var whisper := _formants(_noise(length + 0.15), vowel, [1.0, 0.8, 0.45], 12.0)
	whisper = _shape(whisper, 0.008, length * 0.55)
	var out := _silence_samples(n)
	_mix(out, whisper, 0, 2.2)
	_mix(out, hum, _seconds(0.02), 0.55)
	return out


## 5. Kalimba Oracle: each syllable a plucked wooden tine (inharmonic partials, bent
## along the contour) whose ring is swept from the vowel's F1 up to F2, a little "wah".
func _syl_kalimba(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var ring := maxf(length * 1.6, 0.3)
	var n := _seconds(ring)
	var out := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var sec := float(i) / sample_rate
		var t := clampf(sec / length, 0.0, 1.0)
		phase += lerpf(f0a, f0b, t) / sample_rate
		out[i] = (sin(TAU * phase) * exp(-sec / (ring * 0.45))
			+ 0.25 * sin(TAU * 2.0 * phase) * exp(-sec / (ring * 0.2))
			+ 0.3 * sin(TAU * 5.4 * phase) * exp(-sec / 0.035))
	var wah := _filter_swept(out, "bandpass", _glide_freqs(ring, vowel[0] * 1.2, vowel[1]), 2.5)
	_mix(out, wah, 0, 1.5)
	var click := _shape(_bandpass(_noise(0.02), 3000.0, 2.0), 0.001, 0.012)
	_mix(out, click, 0, 0.3)
	return _shape(out, 0.002, ring)


# --- Round 3: the godly voices --------------------------------------------------------------


## Each godly voice: [base pitch Hz, syllable, reverb feedback (tail length), wet gain, wind].
## Same greeting, wise line and dialogue phrase for all three.
func _render_godly() -> void:
	var voices := {
		"a_choir_of_rings": [233.0, _syl_choir, 0.9, 2.6, 0.0],
		"b_elder_bell_voice": [262.0, _syl_bell_voice, 0.88, 2.0, 0.0],
		"c_breath_of_the_grove": [196.0, _syl_grove, 0.87, 2.2, 0.05],
	}
	for voice in voices:
		var v: Array = voices[voice]
		rng.seed = hash(voice)
		var path: String = "godly/" + voice
		_save(path + "_greeting", _godly_phrase(greeting, v, 1.0), 0.8)
		_save(path + "_wise", _godly_phrase(wise, v, 1.1), 0.8)
		_save(path + "_dialogue", _godly_phrase(dialogue, v, 1.0), 0.8)


const MONGER := "res://assets/audio/voices/mask_monger/"


## The chosen Mask-Monger voice: C's three phrases (same as the godly render), then 8 blips
## (four vowels at two pitches, short and nearly dry: a small 0.6-feedback room instead of
## the hall), meant to be played one per syllable with the bank's pitch jitter.
func _render_monger() -> void:
	var v := [196.0, _syl_grove, 0.87, 2.2, 0.05]
	rng.seed = hash("c_breath_of_the_grove")
	_save(MONGER + "greeting", _godly_phrase(greeting, v, 1.0), 0.8)
	_save(MONGER + "wise_line", _godly_phrase(wise, v, 1.1), 0.8)
	_save(MONGER + "dialogue_blips", _godly_phrase(dialogue, v, 1.0), 0.8)
	var vowels := {"a": A, "e": E, "o": O, "u": U}
	for semis in [0, 4]:
		for vowel_name in vowels:
			var f0: float = v[0] * pow(2.0, semis / 12.0)
			var blip := _silence(0.35)
			_mix(blip, _syl_grove(0.08, f0, f0 * pow(2.0, -0.5 / 12.0), vowels[vowel_name]), 0, 1.0)
			_mix(blip, _hall(blip.duplicate(), 0.6), 0, 0.25)
			_mix(blip, _wind(0.35), 0, v[4])
			blip = _shape(blip, 0.0, 0.33)
			_save(MONGER + "blip_%s_%s" % [vowel_name, "low" if semis == 0 else "high"], blip, 0.7)


## Like _phrase, but through a long hall reverb that stays out of the way while she talks:
## the send is only 7 % during the syllables and opens fully on the last one, and the wet
## signal is ducked under the dry voice, so fast blips stay crisp and the big tail
## blooms only when the line ends.
func _godly_phrase(phrase: Array, v: Array, stretch: float) -> PackedFloat32Array:
	var base: float = v[0]
	var syl: Callable = v[1]
	var tail := 2.4
	var total := tail
	for s in phrase:
		total += (s[2] + s[3]) * stretch
	var dry := _silence(total)
	var send := _silence(total)
	var at := 0
	for k in phrase.size():
		var s: Array = phrase[k]
		var f0a := base * pow(2.0, s[0] / 12.0)
		var f0b := base * pow(2.0, s[1] / 12.0)
		var sound: PackedFloat32Array = syl.call(s[2] * stretch, f0a, f0b, s[4])
		_mix(dry, sound, at, 1.0)
		_mix(send, sound, at, 1.0 if k == phrase.size() - 1 else 0.07)
		at += _seconds((s[2] + s[3]) * stretch)
	var wet := _hall(send, v[2])
	# Duck the wet signal under the dry voice (fast attack, 120 ms release).
	var env := 0.0
	var release := exp(-1.0 / (0.12 * sample_rate))
	var top := 0.001
	for x in dry:
		top = maxf(top, absf(x))
	for i in dry.size():
		env = maxf(absf(dry[i]) / top, env * release)
		wet[i] *= 1.0 - 0.7 * minf(env * 2.0, 1.0)
	_mix(dry, wet, 0, v[3])
	if v[4] > 0.0:
		_mix(dry, _wind(total), 0, v[4])
	return dry


## A. Choir of Rings: four female voices in one mouth (unison detuned a few cents, plus a
## soft fifth above), each with its own vibrato, through the vowel formants, with a faint
## high shimmer partial.
func _syl_choir(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var parts := [[0.0, 1.0, 4.7], [9.0, 0.8, 5.2], [-11.0, 0.8, 5.5], [702.0, 0.3, 4.9]]
	var source := _silence(length + 0.15)
	for p in parts:
		var ratio := pow(2.0, p[0] / 1200.0)
		_mix(source, _glottal(length + 0.15, f0a * ratio, f0b * ratio, p[2], 0.012, 0.002), 0, p[1])
	source = _lowpass(source, 3200.0, 0.7)
	var breath := _highpass(_noise(length + 0.15), 1500.0, 0.7)
	_mix(source, breath, 0, 0.12)
	var out := _formants(source, vowel, [1.0, 0.6, 0.3], 7.0)
	var n := out.size()
	var phase := 0.0
	for i in n:
		phase += lerpf(f0a, f0b, float(i) / n) * 4.0 / sample_rate
		out[i] += 0.06 * sin(TAU * phase)
	return _shape(out, 0.03, length * 0.95)


## B. Elder Bell-Voice: one sung vowel with a wide, slow vibrato, and a singing-bowl of
## inharmonic partials an octave above blooming underneath it. The bowl rings a little past
## the syllable (longer on long syllables).
func _syl_bell_voice(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var ring := clampf(length * 2.5, 0.2, 1.1)
	var voice := _glottal(length + 0.1, f0a, f0b, 4.8, 0.018, 0.002)
	voice = _formants(_lowpass(voice, 2800.0, 0.7), vowel, [1.0, 0.55, 0.25], 8.0)
	voice = _shape(voice, 0.035, length * 0.9)
	var n := _seconds(length + ring)
	var bowl := _silence_samples(n)
	var ratios := [1.0, 2.0, 2.76, 4.07, 5.4]
	var gains := [1.0, 0.45, 0.35, 0.18, 0.1]
	var phase := 0.0
	for i in n:
		var sec := float(i) / sample_rate
		phase += lerpf(f0a, f0b, clampf(sec / length, 0.0, 1.0)) * 2.0 / sample_rate
		var bloom := minf(sec / 0.05, 1.0)
		var x := 0.0
		for r in ratios.size():
			x += gains[r] * sin(TAU * phase * ratios[r]) * exp(-sec * (1.0 + r) / ring)
		bowl[i] = x * bloom
	var out := _silence_samples(n)
	_mix(out, voice, 0, 1.0)
	_mix(out, bowl, 0, 0.22)
	return out


## C. Breath of the Grove: a large whispered vowel resonating in a hollow trunk (fixed
## low wood resonances), carried by a soft hum with a sub-octave for warmth.
func _syl_grove(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var n := _seconds(length + 0.2)
	var whisper := _formants(_noise(length + 0.2), vowel, [1.0, 0.75, 0.4], 11.0)
	whisper = _shape(whisper, 0.015, length * 0.8)
	var hum := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := clampf(float(i) / _seconds(length), 0.0, 1.0)
		phase += lerpf(f0a, f0b, t) * (1.0 + 0.008 * sin(TAU * 4.6 * i / sample_rate)) / sample_rate
		hum[i] = sin(TAU * phase) + 0.3 * sin(TAU * 2.0 * phase) + 0.35 * sin(PI * phase)
	hum = _shape(_lowpass(hum, 1100.0, 0.7), 0.04, length)
	var source := _silence_samples(n)
	_mix(source, whisper, 0, 1.8)
	_mix(source, hum, 0, 0.5)
	var trunk := _formants(source, [210.0, 340.0, 590.0], [0.6, 0.45, 0.3], 14.0)
	_mix(source, trunk, 0, 1.0)
	return source


## Freeverb-style hall: 30 ms pre-delay, six damped combs, two allpasses. `feedback`
## sets the tail (0.9 is about three seconds).
func _hall(x: PackedFloat32Array, feedback: float) -> PackedFloat32Array:
	var pre := _seconds(0.03)
	var input := _silence_samples(x.size())
	for i in range(pre, x.size()):
		input[i] = x[i - pre]
	var out := _silence_samples(x.size())
	for d in [558, 594, 639, 678, 711, 746]:
		var buf := _silence_samples(d)
		var store := 0.0
		var pos := 0
		for i in x.size():
			var y := buf[pos]
			store = y * 0.6 + store * 0.4
			buf[pos] = input[i] + store * feedback
			pos = (pos + 1) % d
			out[i] += y / 6.0
	for d in [278, 220]:
		var buf := _silence_samples(d)
		var pos := 0
		for i in x.size():
			var b := buf[pos]
			buf[pos] = out[i] + b * 0.5
			out[i] = b - out[i]
			pos = (pos + 1) % d
	return out


## Soft wind: low-passed noise swelling slowly, for the grove's air.
func _wind(length: float) -> PackedFloat32Array:
	var out := _bandpass(_noise(length), 500.0, 0.8)
	for i in out.size():
		out[i] *= 0.6 + 0.4 * sin(TAU * 0.35 * i / sample_rate)
	return out


# --- Building blocks ----------------------------------------------------------------------


## A soft glottal pulse train: a sawtooth with a rounded edge, pitch gliding `f0a` to `f0b`
## with vibrato (`vib_rate` Hz, `vib_depth` fraction) and a slow random drift.
func _glottal(length: float, f0a: float, f0b: float, vib_rate: float, vib_depth: float, drift_step: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var out := _silence_samples(n)
	var phase := 0.0
	var drift := 0.0
	for i in n:
		var t := float(i) / n
		drift = clampf(drift + rng.randf_range(-drift_step, drift_step), -0.02, 0.02)
		var f0 := lerpf(f0a, f0b, t) * (1.0 + drift + vib_depth * sin(TAU * vib_rate * i / sample_rate))
		phase = fposmod(phase + f0 / sample_rate, 1.0)
		out[i] = sin(PI * phase) * (2.0 * phase - 1.0)
	return out


## Attack ramp of `attack` s, then an exponential-ish fall over `decay` s. Overrides the
## exponential envelope of synth_base.gd: these voices fade out to silence by `decay`.
func _shape(x: PackedFloat32Array, attack: float, decay: float) -> PackedFloat32Array:
	var out := x.duplicate()
	var a := maxi(_seconds(attack), 1)
	var d := maxi(_seconds(decay), 1)
	for i in out.size():
		var env := minf(float(i) / a, 1.0)
		if i > a:
			env *= pow(clampf(1.0 - float(i - a) / d, 0.0, 1.0), 1.5)
		out[i] *= env
	return out


# --- Output -------------------------------------------------------------------------------


## Normalises to `peak`, fades the last 10 ms, writes 16-bit mono PCM and prints the level.
func _save(file_name: String, x: PackedFloat32Array, peak: float) -> void:
	var out := _normalized(x, peak)
	var fade := mini(_seconds(0.01), out.size())
	for i in fade:
		out[out.size() - 1 - i] *= float(i) / fade
	var sum := 0.0
	var top_out := 0.0
	for v in out:
		sum += v * v
		top_out = maxf(top_out, absf(v))
	var rms := sqrt(sum / out.size())
	print("%s  %.2f s  peak %.1f dBFS  rms %.1f dBFS" % [file_name, float(out.size()) / sample_rate, linear_to_db(top_out), linear_to_db(rms)])
	var path := (file_name if file_name.begins_with("res://") else ROOT + file_name) + ".wav"
	_write_wav(path, out, false)
