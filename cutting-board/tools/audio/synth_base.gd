extends SceneTree

## The building blocks the synth tools share (synth_sfx.gd, synth_music.gd,
## synth_voice_concepts.gd extend this): white noise, envelopes, RBJ biquad filters,
## mixing into buffers, and writing 16-bit mono WAV files. Every buffer is a
## PackedFloat32Array of samples at `sample_rate`.
##
## Randomness comes from `rng`, which each tool seeds per recipe so a run reproduces the
## same files exactly.

## Samples per second. The tools render lo-fi at 22 050 Hz; synth_music.gd raises it for
## its hi-fi rounds.
var sample_rate := 22050
var rng := RandomNumberGenerator.new()


# --- Sources and envelopes ----------------------------------------------------------------


func _noise(length: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## Per-sample filter frequencies gliding linearly from `from` to `to` over `length`.
func _glide_freqs(length: float, from: float, to: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var freqs := PackedFloat32Array()
	freqs.resize(n)
	for i in n:
		freqs[i] = lerpf(from, to, float(i) / n)
	return freqs


## An attack ramp of `attack` seconds, then an exponential decay with time constant
## `decay` seconds.
func _shape(x: PackedFloat32Array, attack: float, decay: float) -> PackedFloat32Array:
	var out := x.duplicate()
	for i in out.size():
		var t := float(i) / sample_rate
		var a := minf(1.0, t / maxf(attack, 0.0001))
		var d := exp(-maxf(t - attack, 0.0) / maxf(decay, 0.0001))
		out[i] *= a * d
	return out


## A rise over the first `rise` of the length and a fall over the last `fall`.
func _ramp(n: int, rise: float, fall: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / n
		out[i] = minf(t / rise, 1.0) * minf((1.0 - t) / fall, 1.0)
	return out


func _softclip(x: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var out := x.duplicate()
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	if peak <= 0.0:
		return out
	for i in out.size():
		out[i] = tanh(out[i] / peak * drive) / tanh(drive)
	return out


# --- Filters ------------------------------------------------------------------------------


## Three (or more) band-passes summed, one per formant, each a little narrower than the
## one before.
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


## An RBJ biquad whose frequency may change every sample; the coefficients are only
## recomputed every 8 samples, which is far below what the ear can hear. A `freqs`
## shorter than `x` holds its last value.
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
			var w0 := TAU * clampf(freqs[mini(i, freqs.size() - 1)], 20.0, sample_rate * 0.45) / sample_rate
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


# --- Buffers ------------------------------------------------------------------------------


## Adds `x` times `gain` into `into` from sample `offset` on; what runs past the end is cut.
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
	return int(round(length * sample_rate))


# --- Output -------------------------------------------------------------------------------


func _normalized(x: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var out := x.duplicate()
	var top := 0.0
	for v in out:
		top = maxf(top, absf(v))
	if top > 0.0:
		for i in out.size():
			out[i] *= peak / top
	return out


## 16-bit mono PCM. A looping file also gets a "smpl" chunk with one forward loop over
## the whole file, which Godot's WAV importer reads as the loop.
func _write_wav(path: String, x: PackedFloat32Array, looping: bool) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, clampi(int(round(x[i] * 32767.0)), -32768, 32767))
	var smpl := PackedByteArray()
	if looping:
		smpl.resize(68)
		smpl.fill(0)
		smpl.encode_u32(0, 0x6c706d73)  # "smpl"
		smpl.encode_u32(4, 60)
		smpl.encode_u32(16, int(1.0e9 / sample_rate))  # sample period, ns
		smpl.encode_u32(20, 60)  # MIDI unity note
		smpl.encode_u32(36, 1)  # one loop
		smpl.encode_u32(48, 0)  # forward
		smpl.encode_u32(52, 0)  # loop start
		smpl.encode_u32(56, x.size() - 1)  # loop end, inclusive
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data.size() + smpl.size())
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(sample_rate)
	file.store_32(sample_rate * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data.size())
	file.store_buffer(data)
	file.store_buffer(smpl)
	file.close()
