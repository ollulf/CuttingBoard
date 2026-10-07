extends "res://tools/audio/synth_base.gd"

## Renders the voice blips of the everyday NPCs, one syllable per file, played one per
## few letters while a line types out (SpeechPlank) through their SoundBanks:
##
##   godot --headless --path cutting-board -s res://tools/audio/synth_npc_voices.gd
##
## - assets/audio/voices/villager/ (resources/audio/villager_voice.tres): warm and
##   friendly, a rounded mid-pitched hum through open vowels with a little breath and a
##   slight upward lilt.
## - assets/audio/voices/bandit/ (resources/audio/bandit_voice.tres): gruff and low, a
##   creaky, uneven buzz (each period a little early or late, a little louder or softer)
##   with rasping noise in it, driven into a soft clip and falling at the end.
##
## Each voice gets 8 blips: four vowels at two pitches. Same lo-fi format and filter
## approach as synth_voice_concepts.gd; seeded per voice, so a run reproduces the files.

const ROOT := "res://assets/audio/voices/"

## Vowel formants (Hz), as in synth_voice_concepts.gd.
const A := [850.0, 1220.0, 2810.0]
const E := [560.0, 2300.0, 2950.0]
const O := [560.0, 1000.0, 2800.0]
const U := [370.0, 950.0, 2700.0]


func _init() -> void:
	var vowels := {"a": A, "e": E, "o": O, "u": U}
	rng.seed = hash("villager_voice")
	for semis in [0, 3]:
		for vowel_name in vowels:
			var f0: float = 210.0 * pow(2.0, semis / 12.0)
			var blip := _villager(0.075, f0, f0 * pow(2.0, 1.0 / 12.0), vowels[vowel_name])
			_save("villager/blip_%s_%s" % [vowel_name, _height(semis)], blip, 0.7)
	rng.seed = hash("bandit_voice")
	for semis in [0, 3]:
		for vowel_name in vowels:
			var f0: float = 98.0 * pow(2.0, semis / 12.0)
			var blip := _bandit(0.09, f0, f0 * pow(2.0, -1.5 / 12.0), vowels[vowel_name])
			_save("bandit/blip_%s_%s" % [vowel_name, _height(semis)], blip, 0.7)
	quit()


func _height(semis: int) -> String:
	return "low" if semis == 0 else "high"


## Villager: a soft rounded pulse with a gentle vibrato, warmed by a sub-octave sine and
## a 2.4 kHz lowpass, through the vowel plus a little breath.
func _villager(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var n := _seconds(length + 0.08)
	var source := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := clampf(float(i) / _seconds(length), 0.0, 1.0)
		var f0 := lerpf(f0a, f0b, t) * (1.0 + 0.01 * sin(TAU * 5.5 * i / sample_rate))
		phase = fposmod(phase + f0 / sample_rate, 1.0)
		source[i] = sin(PI * phase) * (2.0 * phase - 1.0) + 0.25 * sin(TAU * phase)
	source = _lowpass(source, 2400.0, 0.7)
	_mix(source, _noise(length + 0.08), 0, 0.08)
	var voiced := _formants(source, vowel, [1.0, 0.5, 0.2], 6.0)
	_mix(voiced, _lowpass(source, 600.0, 0.7), 0, 0.35)
	return _fade(voiced, 0.012, length + 0.06)


## Bandit: a creaky buzz, its periods jittered in length and level, rough noise riding on
## each pulse, through darker (lowered) vowel formants and a soft clip for grit.
func _bandit(length: float, f0a: float, f0b: float, vowel: Array) -> PackedFloat32Array:
	var n := _seconds(length + 0.08)
	var source := _silence_samples(n)
	var phase := 0.0
	var jitter := 1.0
	var level := 1.0
	var rasp := _noise(length + 0.08)
	for i in n:
		var t := clampf(float(i) / _seconds(length), 0.0, 1.0)
		var f0 := lerpf(f0a, f0b, t) * jitter
		phase += f0 / sample_rate
		if phase >= 1.0:
			phase -= 1.0
			jitter = 1.0 + rng.randf_range(-0.08, 0.08)
			level = rng.randf_range(0.6, 1.0)
		var pulse := (2.0 * phase - 1.0) * level
		# Breathy rasp, loudest right after each glottal closure.
		source[i] = pulse + rasp[i] * 0.55 * (1.0 - phase) * level
	var dark := []
	for f in vowel:
		dark.append(f * 0.85)
	var voiced := _formants(source, dark, [1.0, 0.6, 0.3], 5.0)
	_mix(voiced, _lowpass(source, 350.0, 0.8), 0, 0.5)
	voiced = _softclip(voiced, 2.5)
	voiced = _lowpass(voiced, 3200.0, 0.7)
	return _fade(voiced, 0.008, length + 0.05)


## A linear rise over `attack` seconds, then a 1.5-power fall to silence by `total`.
func _fade(x: PackedFloat32Array, attack: float, total: float) -> PackedFloat32Array:
	var out := x.duplicate()
	var a := maxi(_seconds(attack), 1)
	var d := maxi(_seconds(total) - a, 1)
	for i in out.size():
		var env := minf(float(i) / a, 1.0)
		if i > a:
			env *= pow(clampf(1.0 - float(i - a) / d, 0.0, 1.0), 1.5)
		out[i] *= env
	return out


## Normalises to `peak` and writes 16-bit mono PCM under ROOT.
func _save(file_name: String, x: PackedFloat32Array, peak: float) -> void:
	_write_wav(ROOT + file_name + ".wav", _normalized(x, peak), false)
	print("%s  %.2f s" % [file_name, float(x.size()) / sample_rate])
