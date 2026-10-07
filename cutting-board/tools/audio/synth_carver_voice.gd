extends "res://tools/audio/synth_base.gd"

## Renders three Carver voice concepts (docs/concepts/carver-voice.md) as WAVs in
## assets/audio/voice_concepts/carver/: per concept a greeting, a slow "wise" line and a
## fast dialogue sample, all babble blips, not words. Darker than the Mask-Monger's voice
## (low, ageless, male-ish), slightly godly (long hall, choir and bell hints) and weird
## (wood creak, detuned and many-mouthed layers). Concept sketches only, not wired in:
##
##   godot --headless --path cutting-board -s res://tools/audio/synth_carver_voice.gd
##
## Same phrases as the Monger's round 3 (synth_voice_concepts.gd), so they compare
## directly. The hall, glottal source and envelope are copies of that script's helpers,
## kept separate so the two tools can change independently.

const ROOT := "res://assets/audio/voice_concepts/carver/"

## Male vowel formants (F1, F2, F3 in Hz), roughly from Peterson & Barney, lowered 8 %
## for a bigger, hollower body.
const A := [672.0, 1003.0, 2245.0]
const E := [488.0, 1693.0, 2282.0]
const I := [248.0, 2107.0, 2769.0]
const O := [524.0, 773.0, 2217.0]
const U := [276.0, 800.0, 2061.0]

## A syllable: [semitones at start, semitones at end, length s, pause after s, vowel].
var greeting := [
	[0, 2, 0.13, 0.03, E], [4, 3, 0.11, 0.03, A], [5, 5, 0.10, 0.03, O], [7, 4, 0.22, 0.14, A],
	[3, 2, 0.11, 0.03, I], [2, 0, 0.12, 0.03, E], [0, -2, 0.13, 0.04, O], [-3, -5, 0.40, 0.0, U],
]
var wise := [
	[-2, 0, 0.22, 0.07, O], [0, 0, 0.18, 0.07, A], [3, 2, 0.26, 0.07, E], [2, 0, 0.32, 0.38, O],
	[0, 1, 0.20, 0.07, I], [-1, -2, 0.22, 0.07, A], [-3, -3, 0.22, 0.08, E], [-5, -7, 0.75, 0.0, U],
]
var dialogue := [
	[0, 1, 0.07, 0.02, E], [2, 2, 0.06, 0.02, A], [3, 2, 0.07, 0.02, O], [1, 1, 0.06, 0.02, I],
	[2, 3, 0.07, 0.02, A], [4, 4, 0.06, 0.02, E], [3, 2, 0.07, 0.02, U], [2, 1, 0.06, 0.02, O],
	[0, 0, 0.08, 0.02, A], [-1, -2, 0.12, 0.22, E],
	[2, 3, 0.07, 0.02, I], [4, 3, 0.06, 0.02, A], [3, 3, 0.07, 0.02, O], [2, 2, 0.06, 0.02, E],
	[1, 2, 0.07, 0.02, A], [3, 2, 0.06, 0.02, U], [1, 0, 0.07, 0.02, O], [0, -1, 0.06, 0.02, I],
	[-2, -2, 0.08, 0.02, E], [-3, -5, 0.24, 0.0, A],
]


## Each voice: [base pitch Hz, syllable, reverb feedback (tail length), wet gain, swell].
## `swell` is the gain of a reversed-reverb breath that rises into the first syllable.
func _init() -> void:
	var voices := {
		"a_hollow_idol": [98.0, _syl_idol, 0.91, 2.4, 0.0],
		"b_splinter_bell": [87.0, _syl_splinter, 0.89, 2.0, 0.0],
		"c_many_mouths": [104.0, _syl_mouths, 0.9, 2.2, 0.5],
	}
	for voice in voices:
		var v: Array = voices[voice]
		rng.seed = hash("carver_" + voice)
		_save(voice + "_greeting", _phrase(greeting, v, 1.0), 0.8)
		_save(voice + "_wise", _phrase(wise, v, 1.15), 0.8)
		_save(voice + "_dialogue", _phrase(dialogue, v, 1.0), 0.8)
	quit()


# --- The three voices -----------------------------------------------------------------------


## A. Hollow Idol: a low, slow-vibrato male voice doubled by a whispered choir an octave up
## (three detuned throats) and a sub-octave hum, all ringing in a hollow wooden head. The
## voice of a statue that has been listening for a very long time.
func _syl_idol(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var n := _seconds(length + 0.2)
	var voice := _glottal(length + 0.2, f0a, f0b, 3.8, 0.012, 0.002)
	voice = _lowpass(voice, 1900.0, 0.7)
	var sub := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := clampf(float(i) / _seconds(length), 0.0, 1.0)
		phase += lerpf(f0a, f0b, t) * 0.5 / sample_rate
		sub[i] = sin(TAU * phase)
	_mix(voice, sub, 0, 0.35)
	var choir := _silence_samples(n)
	for cents in [-14.0, 0.0, 11.0]:
		var r := 2.0 * pow(2.0, cents / 1200.0)
		_mix(choir, _glottal(length + 0.2, f0a * r, f0b * r, 5.1, 0.01, 0.003), 0, 0.3)
	_mix(choir, _highpass(_noise(length + 0.2), 1200.0, 0.7), 0, 0.25)
	var out := _formants(voice, vowel, [1.0, 0.5, 0.2], 8.0)
	_mix(out, _formants(choir, vowel, [0.6, 0.5, 0.35], 10.0), 0, 0.8)
	_mix(out, _formants(out, [180.0, 310.0, 520.0], [0.5, 0.4, 0.25], 16.0), 0, 0.9)
	return _shape(out, 0.04, length * 0.95)


## B. Splinter Bell: a bowed-wood stick-slip throat (each period a little early or late,
## louder or softer) that grinds in from a creaky fry, plus a dark bronze bell a tritone
## below that blooms on each syllable. Wood under the knife, struck in a temple.
func _syl_splinter(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var n := _seconds(length + 0.12)
	var source := _silence_samples(n)
	var phase := 0.0
	var amp := 1.0
	var jitter := 0.0
	var fry := 0.09
	for i in n:
		var t := clampf(float(i) / _seconds(length), 0.0, 1.0)
		var sec := float(i) / sample_rate
		var f0 := lerpf(f0a, f0b, t)
		if sec < fry:
			f0 = lerpf(24.0, f0, pow(sec / fry, 2.5))
		phase += f0 * (1.0 + jitter) / sample_rate
		if phase >= 1.0:
			phase -= 1.0
			amp = rng.randf_range(0.45, 1.0)
			jitter = rng.randf_range(-0.05, 0.05)
		source[i] = (2.0 * phase - 1.0) * amp
	var scrape := _bandpass(_noise(length + 0.12), 1800.0, 1.5)
	for i in n:
		scrape[i] *= absf(source[i])
	_mix(source, scrape, 0, 0.5)
	var throat := _formants(source, [240.0, 430.0, 980.0, 2100.0], [0.8, 1.0, 0.5, 0.25], 11.0)
	_mix(throat, _formants(source, vowel, [0.8, 0.45, 0.15], 9.0), 0, 1.0)
	throat = _shape(throat, 0.02, length * 0.9)
	var ring := clampf(length * 3.0, 0.3, 1.4)
	var m := _seconds(length + ring)
	var bell := _silence_samples(m)
	var ratios := [1.0, 2.32, 3.17, 4.53]
	var gains := [1.0, 0.5, 0.3, 0.15]
	var bphase := 0.0
	var tritone := pow(2.0, -6.0 / 12.0) * 2.0
	for i in m:
		var sec := float(i) / sample_rate
		bphase += lerpf(f0a, f0b, clampf(sec / length, 0.0, 1.0)) * tritone / sample_rate
		var x := 0.0
		for r in ratios.size():
			x += gains[r] * sin(TAU * bphase * ratios[r]) * exp(-sec * (1.0 + 1.5 * r) / ring)
		bell[i] = x * minf(sec / 0.04, 1.0)
	var out := _silence_samples(m)
	_mix(out, throat, 0, 1.0)
	_mix(out, bell, 0, 0.18)
	return out


## C. Many Mouths: one syllable spoken by three mouths at once, a low throat, a ghost a
## minor ninth above, and a ring-modulated whisper, each a few ms apart and on a shifted
## vowel, so the words smear like an echo of many masks. A reversed breath rises into
## each phrase.
func _syl_mouths(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var n := _seconds(length + 0.2)
	var out := _silence_samples(n)
	var low := _glottal(length + 0.2, f0a, f0b, 4.2, 0.01, 0.002)
	low = _formants(_lowpass(low, 1600.0, 0.7), vowel, [1.0, 0.45, 0.2], 9.0)
	_mix(out, _shape(low, 0.03, length * 0.9), 0, 1.0)
	var r := pow(2.0, 13.0 / 12.0)
	var ghost := _glottal(length + 0.2, f0a * r, f0b * r * 0.98, 6.3, 0.02, 0.004)
	var shifted := [vowel[0] * 1.15, vowel[1] * 0.9, vowel[2]]
	ghost = _formants(_lowpass(ghost, 2600.0, 0.7), shifted, [0.8, 0.6, 0.3], 9.0)
	_mix(out, _shape(ghost, 0.05, length * 0.8), _seconds(0.018), 0.4)
	var whisper := _formants(_noise(length + 0.2), vowel, [1.0, 0.8, 0.4], 12.0)
	var phase := 0.0
	for i in n:
		phase += 37.0 / sample_rate
		whisper[i] *= sin(TAU * phase)
	_mix(out, _shape(whisper, 0.01, length * 0.6), _seconds(0.035), 1.2)
	_mix(out, _formants(out, [200.0, 360.0], [0.5, 0.35], 15.0), 0, 0.8)
	return out


# --- Phrase and hall --------------------------------------------------------------------------


## Lays the syllables end to end and sends them into a long hall that stays out of the way
## while he talks: the send is 8 % during the syllables and opens fully on the last one,
## and the wet signal is ducked under the dry voice (as the Monger's godly voices do).
func _phrase(phrase: Array, v: Array, stretch: float) -> PackedFloat32Array:
	var base: float = v[0]
	var syl: Callable = v[1]
	var lead := 0.5 if v[4] > 0.0 else 0.0
	var tail := 2.8
	var total := lead + tail
	for s in phrase:
		total += (s[2] + s[3]) * stretch
	var dry := _silence(total)
	var send := _silence(total)
	var at := _seconds(lead)
	for k in phrase.size():
		var s: Array = phrase[k]
		var f0a := base * pow(2.0, s[0] / 12.0)
		var f0b := base * pow(2.0, s[1] / 12.0)
		var sound: PackedFloat32Array = syl.call(s[2] * stretch, f0a, f0b, s[4])
		_mix(dry, sound, at, 1.0)
		_mix(send, sound, at, 1.0 if k == phrase.size() - 1 else 0.08)
		at += _seconds((s[2] + s[3]) * stretch)
	var wet := _hall(send, v[2])
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
		_mix(dry, _reverse_swell(lead), 0, v[4])
	return dry


## A whispered breath through the hall, reversed, so it swells up to the first word.
func _reverse_swell(length: float) -> PackedFloat32Array:
	var breath := _silence(length + 0.6)
	_mix(breath, _shape(_formants(_noise(0.25), O, [1.0, 0.7, 0.3], 10.0), 0.01, 0.22), 0, 1.0)
	var wet := _hall(breath, 0.88)
	wet.reverse()
	var out := _silence(length)
	for i in out.size():
		out[i] = wet[wet.size() - out.size() + i] if wet.size() >= out.size() else 0.0
	return _normalized(out, 0.4)


## Freeverb-style hall (copy of synth_voice_concepts.gd's): 30 ms pre-delay, six damped
## combs, two allpasses. `feedback` sets the tail (0.9 is about three seconds).
func _hall(x: PackedFloat32Array, feedback: float) -> PackedFloat32Array:
	var pre := _seconds(0.03)
	var input := _silence_samples(x.size())
	for i in range(pre, x.size()):
		input[i] = x[i - pre]
	var out := _silence_samples(x.size())
	for d in [601, 647, 691, 733, 769, 811]:
		var buf := _silence_samples(d)
		var store := 0.0
		var pos := 0
		for i in x.size():
			var y := buf[pos]
			store = y * 0.5 + store * 0.5
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


## Attack ramp of `attack` s, then a fall to silence over `decay` s (overrides synth_base.gd's
## exponential envelope, as synth_voice_concepts.gd does).
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
	_write_wav(ROOT + file_name + ".wav", out, false)
