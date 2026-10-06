extends SceneTree

## Renders the five Mask-Monger voice concepts (docs/concepts/monger-voice.md) as WAVs in
## assets/audio/voice_concepts/: per concept a short greeting of babble blips and a
## slower, falling "wise" line. Concept sketches only, not wired into any SoundBank:
##
##   godot --headless --path cutting-board -s res://tools/audio/synth_voice_concepts.gd
##
## Every concept speaks the same two phrases (same syllable pitches, lengths and vowels),
## so the files compare the voice itself, not the melody. Same lo-fi format and filter
## approach as synth_sfx.gd; prints peak and RMS level of each file.

const RATE := 22050
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

var rng := RandomNumberGenerator.new()


func _init() -> void:
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
		var f0 := lerpf(f0a, f0b, t * t) * (1.0 + wobble + 0.008 * sin(TAU * 4.5 * i / RATE))
		phase += f0 / RATE
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
		var sec := float(i) / RATE
		var f0 := lerpf(f0a, f0b, t)
		if sec < fry:
			f0 = lerpf(38.0, f0, pow(sec / fry, 3.0))
		phase += f0 * (1.0 + jitter) / RATE
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
		phase += lerpf(f0a, f0b, t) * (1.0 + 0.01 * sin(TAU * 5.5 * i / RATE)) / RATE
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
		var sec := float(i) / RATE
		var t := clampf(sec / length, 0.0, 1.0)
		phase += lerpf(f0a, f0b, t) / RATE
		out[i] = (sin(TAU * phase) * exp(-sec / (ring * 0.45))
			+ 0.25 * sin(TAU * 2.0 * phase) * exp(-sec / (ring * 0.2))
			+ 0.3 * sin(TAU * 5.4 * phase) * exp(-sec / 0.035))
	var wah := _filter_swept(out, "bandpass", _glide_freqs(ring, vowel[0] * 1.2, vowel[1]), 2.5)
	_mix(out, wah, 0, 1.5)
	var click := _shape(_bandpass(_noise(0.02), 3000.0, 2.0), 0.001, 0.012)
	_mix(out, click, 0, 0.3)
	return _shape(out, 0.002, ring)


# --- Building blocks (as in synth_sfx.gd) -------------------------------------------------


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
		var f0 := lerpf(f0a, f0b, t) * (1.0 + drift + vib_depth * sin(TAU * vib_rate * i / RATE))
		phase = fposmod(phase + f0 / RATE, 1.0)
		out[i] = sin(PI * phase) * (2.0 * phase - 1.0)
	return out


func _glide_freqs(length: float, from: float, to: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var freqs := PackedFloat32Array()
	freqs.resize(n)
	for i in n:
		freqs[i] = lerpf(from, to, float(i) / n)
	return freqs


func _noise(length: float) -> PackedFloat32Array:
	var out := _silence(length)
	for i in out.size():
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## Attack ramp of `attack` s, then an exponential-ish fall over `decay` s.
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


func _formants(x: PackedFloat32Array, freqs: Array, gains: Array, q: float) -> PackedFloat32Array:
	var out := _silence_samples(x.size())
	for f in freqs.size():
		_mix(out, _bandpass(x, freqs[f], q * (1.0 + f * 0.5)), 0, gains[f])
	return out


func _lowpass(x: PackedFloat32Array, freq: float, q: float) -> PackedFloat32Array:
	return _biquad(x, "lowpass", freq, q)


func _highpass(x: PackedFloat32Array, freq: float, q: float) -> PackedFloat32Array:
	return _biquad(x, "highpass", freq, q)


func _bandpass(x: PackedFloat32Array, freq: float, q: float) -> PackedFloat32Array:
	return _biquad(x, "bandpass", freq, q)


func _biquad(x: PackedFloat32Array, type: String, freq: float, q: float) -> PackedFloat32Array:
	var freqs := PackedFloat32Array()
	freqs.resize(x.size())
	freqs.fill(freq)
	return _filter_swept(x, type, freqs, q)


## RBJ biquad with a per-sample frequency, coefficients refreshed every 8 samples.
func _filter_swept(x: PackedFloat32Array, type: String, freqs: PackedFloat32Array, q: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	for i in x.size():
		if i % 8 == 0:
			var w0 := TAU * clampf(freqs[mini(i, freqs.size() - 1)], 20.0, RATE * 0.45) / RATE
			var cw := cos(w0)
			var alpha := sin(w0) / (2.0 * q)
			var a0 := 1.0 + alpha
			match type:
				"lowpass":
					b0 = (1.0 - cw) * 0.5
					b1 = 1.0 - cw
					b2 = b0
				"highpass":
					b0 = (1.0 + cw) * 0.5
					b1 = -(1.0 + cw)
					b2 = b0
				_:
					b0 = alpha
					b1 = 0.0
					b2 = -alpha
			b0 /= a0
			b1 /= a0
			b2 /= a0
			a1 = -2.0 * cw / a0
			a2 = (1.0 - alpha) / a0
		var v := b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		out[i] = v
	return out


func _mix(into: PackedFloat32Array, x: PackedFloat32Array, offset: int, gain: float) -> void:
	for i in x.size():
		var j := offset + i
		if j >= into.size():
			return
		into[j] += x[i] * gain


func _silence(length: float) -> PackedFloat32Array:
	return _silence_samples(_seconds(length))


func _silence_samples(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	return out


func _seconds(length: float) -> int:
	return int(round(length * RATE))


# --- Output -------------------------------------------------------------------------------


## Normalises to `peak`, fades the last 10 ms, writes 16-bit mono PCM and prints the level.
func _save(file_name: String, x: PackedFloat32Array, peak: float) -> void:
	var out := x.duplicate()
	var top := 0.0
	for v in out:
		top = maxf(top, absf(v))
	if top > 0.0:
		for i in out.size():
			out[i] *= peak / top
	var fade := mini(_seconds(0.01), out.size())
	for i in fade:
		out[out.size() - 1 - i] *= float(i) / fade
	var sum := 0.0
	var top_out := 0.0
	for v in out:
		sum += v * v
		top_out = maxf(top_out, absf(v))
	var rms := sqrt(sum / out.size())
	print("%s  %.2f s  peak %.1f dBFS  rms %.1f dBFS" % [file_name, float(out.size()) / RATE, linear_to_db(top_out), linear_to_db(rms)])
	var path := ROOT + file_name + ".wav"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var data := PackedByteArray()
	data.resize(out.size() * 2)
	for i in out.size():
		data.encode_s16(i * 2, clampi(int(round(out[i] * 32767.0)), -32768, 32767))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data.size())
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(RATE)
	file.store_32(RATE * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data.size())
	file.store_buffer(data)
	file.close()
