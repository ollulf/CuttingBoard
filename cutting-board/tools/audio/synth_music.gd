extends SceneTree

## Renders the music concept sketches in assets/audio/music/concepts from code: the wood
## leitmotif and the two cues built on it (the village, and outside the village at night).
##
##   godot --headless --path cutting-board -s res://tools/audio/synth_music.gd
##   godot --headless --path cutting-board -s res://tools/audio/synth_music.gd -- --only=village
##
## then `godot --headless --path cutting-board --import` to reimport. Needs ffmpeg on the
## PATH to write OGG Vorbis; without it the WAVs are left in user://music_render instead.
##
## Every instrument is made of wood (or at least sounds it): marimba and xylophone bars as
## sums of decaying inharmonic sines, wood and temple blocks, a slit log drum, hyoshigi
## clappers, binzasara bead rattles, a tanuki belly drum, taiko, a plucked shamisen
## (Karplus-Strong), a shinobue bamboo flute, a mukkuri bamboo jaw harp, a creaking
## board and a knocked door. No recorded audio. Like synth_sfx.gd the output is lo-fi on
## purpose, mono 22 050 Hz, and the small Schroeder reverb is a nod to the PS1 SPU's.
##
## The scores are plain text, one token per note: `D5:2` is D5 for two sixteenths, `r:4`
## a rest, `Ab4/A4:4` a note that slides (or, on a struck bar, grace-notes) into another,
## a trailing `!` an accent and `|` a bar line. The leitmotif is MOTIF below; the cues
## quote it whole, transpose it, stretch it, flatten its fifth or play only some of its
## bars. Drum parts are sixteen-step patterns: `x` hit, `X` accent, `o` ghost, `.` rest.
##
## The cues loop: every note and the reverb and echo tails are wrapped around the loop
## end onto its start, so the file loops without a seam or a crossfade.

const RATE := 22050
const ROOT := "res://assets/audio/music/concepts/"

## The leitmotif, in D min'yo (D F G A C): a double knock on wood, a cheeky leap up,
## a tumble down; then the same knock higher, and a wrong-footed slide from Ab into A
## before the bottom drops out onto a low D.
const MOTIF := "D5:2 D5:2 r:2 A5:4 G5:2 F5:2 G5:2 | D5:6 C5:2 A4:4 r:4 | D5:2 D5:2 r:2 A5:4 C6:2 A5:2 G5:2 | F5:2 D5:2 C5:2 Ab4/A4:4 r:2 D4:4!"

var rng := RandomNumberGenerator.new()

## The buses a cue is mixed into: dry, the reverb send and the echo send.
var _dry := PackedFloat32Array()
var _verb := PackedFloat32Array()
var _echo := PackedFloat32Array()
## Whether notes past the end wrap around to the start.
var _loop := false
## Seconds per sixteenth note.
var _step := 0.125
var _cache := {}


func _init() -> void:
	var only: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	var cues := {
		"leitmotif": _make_leitmotif,
		"village": _make_village,
		"outside": _make_outside,
	}
	for cue in cues:
		if not only.is_empty() and not only.has(cue):
			continue
		rng.seed = hash(cue)
		var started := Time.get_ticks_msec()
		(cues[cue] as Callable).call()
		print("%s  (%d ms)" % [cue, Time.get_ticks_msec() - started])
	quit()


# --- Cues ---------------------------------------------------------------------------------


## The motif stated twice: first bare on a marimba over a bass bar and a woodblock, then
## on the bamboo flute with the whole festival behind it. The hyoshigi open it the way
## they open a kabuki play, clacking faster and faster.
func _make_leitmotif() -> void:
	_begin(112.0, 10, false, 2.0)
	for s in [0, 6, 10, 13, 15]:
		_hit("hyoshigi", 84, s, 1.0 - s * 0.03, 0.35)
	_line("marimba", 1, MOTIF, 0.9, 0.2)
	for bar in range(1, 9):
		var root: int = [50, 50, 48, 45][(bar - 1) % 4]
		_hit("marimba", root, bar * 16, 0.7, 0.15)
		_hit("marimba", root + 7, bar * 16 + 8, 0.45, 0.15)
		_pattern("woodblock", bar, 1, "....x.......x...", 79, 0.5, 0.15)
	_line("shinobue", 5, MOTIF, 0.75, 0.3)
	_line("marimba", 5, MOTIF, 0.55, 0.2, -12)
	_pattern("belly", 5, 4, "x.....x.x.....x.", 45, 0.8, 0.15)
	_pattern("taiko", 5, 4, "x.......x.x.....", 0, 0.7, 0.25)
	_pattern("ka", 5, 4, "....x.......x..x", 0, 0.45, 0.15)
	_shamisen_offbeats(5, 4, [50, 50, 48, 45])
	_pattern("taiko", 8, 1, "........x.x.xxX.", 0, 0.75, 0.25)
	_hit("taiko", 0, 9 * 16, 1.0, 0.35)
	_hit("logdrum", 38, 9 * 16, 1.0, 0.35)
	_hit("hyoshigi", 84, 9 * 16, 1.0, 0.45)
	_finish("leitmotif", 0.18)


## The village at the fair: warm, busy, the motif played straight. Four sections of
## eight bars: the groove alone and then the motif on marimba; the motif on flute with
## taiko; call and response between marimba, temple blocks and xylophone, broken by a
## slide-whistle swell, a bonk and a beat of stunned silence; then everyone at once.
func _make_village() -> void:
	_begin(112.0, 32, true)
	var roots := [50, 50, 48, 45]
	# The groove under everything, except where the bonk stops the music in bar 20.
	for bar in 32:
		var root: int = roots[bar % 4]
		if bar != 20:
			_hit("marimba", root, bar * 16, 0.75, 0.15)
			_hit("marimba", root, bar * 16 + 6, 0.5, 0.15)
		_hit("marimba", root + 7, bar * 16 + 8, 0.55, 0.15)
		_hit("marimba", root + 12, bar * 16 + 12, 0.4, 0.15)
		if bar == 20:
			_pattern("belly", bar, 1, "........x.x...x.", 45, 0.85, 0.15)
			continue
		_pattern("belly", bar, 1, "x.....x.x.....x." if bar % 2 == 0 else "x.....x.x...x.x.", 45, 0.8, 0.15)
		_pattern("woodblock", bar, 1, "..x...x...x...x.", 79, 0.4, 0.1)
		_pattern("binzasara", bar, 1, "x.o.x.oox.o.x.oo", 0, 0.35, 0.05)
	_hit("hyoshigi", 84, 0, 1.0, 0.4)
	_hit("hyoshigi", 84, 3, 0.7, 0.4)

	# A: the motif comes in on marimba over the groove.
	_line("marimba", 4, MOTIF, 0.9, 0.2)
	_shamisen_offbeats(4, 4, roots)

	# B: the flute takes it, the marimba shadows it an octave down, taiko joins.
	_line("shinobue", 8, MOTIF, 0.8, 0.3)
	_line("shinobue", 12, MOTIF, 0.8, 0.3)
	_line("marimba", 8, MOTIF, 0.45, 0.15, -12)
	_line("marimba", 12, MOTIF, 0.45, 0.15, -12)
	_pattern("taiko", 8, 7, "x.......x.x.....", 0, 0.6, 0.25)
	_pattern("ka", 8, 7, "....x.......x...", 0, 0.4, 0.15)
	_pattern("taiko", 15, 1, "x...x...x.x.x.xX", 0, 0.7, 0.25)
	_hit("hyoshigi", 84, 16 * 16, 1.0, 0.4)

	# C: call and response, then the comic swell and the bonk.
	var bars := MOTIF.split("|")
	_line("marimba", 16, bars[0], 0.9, 0.2)
	_line("templeblock", 17, "D5:2 D5:2 r:2 A5:4 G5:2 F5:2 G5:2", 0.8, 0.25)
	_line("xylophone", 18, bars[2], 0.8, 0.2)
	_hit("slidewhistle", 62, 19 * 16, 0.8, 0.3, 16.0, 74)
	_pattern("taiko", 19, 1, "x.o.x.o.xoxoxxxx", 0, 0.6, 0.25)
	_hit("logdrum", 38, 20 * 16, 1.0, 0.35)
	_hit("hyoshigi", 84, 20 * 16, 1.0, 0.45)
	_hit("doorknock", 0, 20 * 16 + 4, 0.6, 0.3)
	_line("shinobue", 21, bars[1] + "|" + bars[2] + "|" + bars[3], 0.8, 0.3)
	_shamisen_offbeats(21, 3, roots)

	# D: everyone. Flute and xylophone in unison, marimba an octave down.
	_line("shinobue", 24, MOTIF + "|" + MOTIF, 0.85, 0.3)
	_line("xylophone", 24, MOTIF + "|" + MOTIF, 0.55, 0.2)
	_line("marimba", 24, MOTIF + "|" + MOTIF, 0.5, 0.15, -12)
	_shamisen_offbeats(24, 8, roots)
	_pattern("taiko", 24, 7, "x.......x.x.....", 0, 0.7, 0.25)
	_pattern("ka", 24, 7, "....x..x....x...", 0, 0.45, 0.15)
	_pattern("taiko", 31, 1, "x.......x.x.xxX.", 0, 0.8, 0.25)
	_finish("village", 0.16)


## Outside the village at night: slow, sparse and a little wrong. A marimba roll hums a
## drone whose fifth keeps sagging to a tritone, a slit drum thuds far off with an echo,
## somebody knocks and the woods knock back (once with one knock too many, once with the
## motif itself). The flute plays the motif at half speed with its fifth flattened, until
## the second half comes back in tune; a bamboo jaw harp boings and a distant tanuki
## drums its belly.
func _make_outside() -> void:
	_begin(76.0, 24, true)
	var bars := MOTIF.split("|")
	# The drone: a soft marimba roll on D3 and a fifth that sometimes sags to Ab.
	var tops := [57, 57, 56, 57, 56, 57]
	for bar in 24:
		var top: int = tops[int(bar / 4.0)]
		var swell := 0.5 + 0.5 * sin(TAU * (bar * 16) / (24.0 * 16.0) * 3.0)
		for s in 16:
			var note: int = 50 if s % 2 == 0 else top
			_hit("marimba", note, bar * 16 + s, rng.randf_range(0.12, 0.17) * (0.6 + 0.4 * swell), 0.4)
		if bar % 2 == 0:
			_hit("logdrum", 38, bar * 16, 0.8, 0.35, 2.0, -1, 0.45)
			_hit("logdrum", 45, bar * 16 + 10, 0.4, 0.35, 2.0, -1, 0.45)

	# Knock knock; who's there?
	_knocks(2, [0, 3], 0.9, false)
	_knocks(3, [4, 7], 0.5, true)
	_knocks(10, [0, 3], 0.9, false)
	_knocks(11, [2, 5, 13], 0.5, true)
	_knocks(18, [0, 3], 0.9, false)
	_line("templeblock", 19, "D5:2 D5:2 r:2 A5:4 r:6", 0.45, 0.55)

	# The motif at half speed on the flute, its fifth flattened, then the tumble in tune.
	_line("shinobue", 4, bars[0] + "|" + bars[1], 0.32, 0.55, 0, 2.0, {9: -1})
	_line("shinobue", 12, bars[2] + "|" + bars[3], 0.32, 0.55, 0, 2.0)
	# A crooked xylophone, a little out of tune with itself, picking at the knock.
	_line("xylo_detuned", 8, "D6:2 D6:2 r:12 | r:4 Ab5:2 r:10 | D6:2 D6:2 r:4 Eb6:4 r:4 | r:16", 0.5, 0.6)
	_line("xylophone", 20, bars[3], 0.5, 0.5, 0, 2.0)

	# Boing.
	_pattern("mukkuri", 16, 4, "x.....x.x.......", 38, 0.6, 0.3)
	_pattern("belly", 16, 8, "x.......x.x.....", 45, 0.3, 0.6, 0.4)
	for at in [[7, 4], [15, 8], [22, 0]]:
		_hit("creak", 0, at[0] * 16 + at[1], 0.6, 0.45)
	_finish("outside", 0.3, 0.42)


## Somebody knocks on a door; with `far`, the knocks come back from the woods.
func _knocks(bar: int, steps: Array, vel: float, far: bool) -> void:
	for s in steps:
		_hit("doorknock_far" if far else "doorknock", 0, bar * 16 + s, vel, 0.6 if far else 0.25, 2.0, -1, 0.35 if far else 0.0)


## Plucked shamisen fifths on the offbeats, following the bass roots.
func _shamisen_offbeats(bar: int, count: int, roots: Array) -> void:
	for b in range(bar, bar + count):
		var root: int = roots[b % roots.size()]
		for s in [2, 6, 10, 14]:
			_hit("shamisen", root + 12, b * 16 + s, 0.4, 0.15)
			_hit("shamisen", root + 19, b * 16 + s, 0.3, 0.15)


# --- Sequencing ---------------------------------------------------------------------------


## Starts a cue `bars` of 4/4 long at `bpm`. A looping cue wraps everything that rings
## past its end; a one-shot gets `tail` seconds to ring out instead.
func _begin(bpm: float, bars: int, loop: bool, tail := 0.0) -> void:
	_step = 60.0 / bpm / 4.0
	_loop = loop
	var n := _seconds(bars * 16 * _step + tail)
	_dry = _silence_samples(n)
	_verb = _silence_samples(n)
	_echo = _silence_samples(n)


## Plays a text score (see the header) on `inst` from bar `bar`. `transpose` shifts it in
## semitones, `stretch` scales its durations, and `pitch_map` moves pitch classes, e.g.
## {9: -1} flattens every A.
func _line(inst: String, bar: int, text: String, vel: float, verb: float, transpose := 0, stretch := 1.0, pitch_map := {}) -> void:
	var at := float(bar * 16)
	for measure in text.split("|"):
		var length := 0.0
		for token in measure.strip_edges().split(" ", false):
			var accent := token.ends_with("!")
			var parts := token.trim_suffix("!").split(":")
			var steps := float(parts[1])
			length += steps
			if parts[0] != "r":
				var pitches := parts[0].split("/")
				var midi := _mapped(_midi(pitches[0]) + transpose, pitch_map)
				var glide := _mapped(_midi(pitches[1]) + transpose, pitch_map) if pitches.size() > 1 else -1
				_hit(inst, midi, at, vel * (1.25 if accent else 1.0), verb, steps * stretch, glide)
			at += steps * stretch
		if not is_equal_approx(length, 16.0):
			push_warning("%s: a bar of %s sixteenths in '%s'" % [inst, length, measure])


## Plays a sixteen-step pattern (repeated if shorter than `bars`) on `inst` at `midi`.
func _pattern(inst: String, bar: int, bars: int, pattern: String, midi: int, vel: float, verb: float, echo := 0.0) -> void:
	for s in bars * 16:
		var c := pattern[s % pattern.length()]
		if c != ".":
			var v := vel * (1.3 if c == "X" else 0.45 if c == "o" else 1.0)
			_hit(inst, midi, bar * 16 + s, v, verb, 1.0, -1, echo)


## One note: `inst` at `midi` (sliding to `glide` if it is not -1) at sixteenth `at`,
## `steps` long. Struck instruments get a few milliseconds of slop and a little
## velocity jitter, so the groove doesn't sound like a sequencer.
func _hit(inst: String, midi: float, at: float, vel: float, verb: float, steps := 2.0, glide := -1, echo := 0.0) -> void:
	var sustained := inst in ["shinobue", "slidewhistle"]
	var length := steps * _step
	var t := at * _step
	if not sustained:
		t += rng.randf_range(-0.004, 0.004)
		vel *= rng.randf_range(0.9, 1.05)
		if glide >= 0:
			# A struck bar can't slide: play the first pitch as a grace note.
			_mix_bus(_note(inst, midi, length, -1), t - _step * 0.5, vel * 0.7, verb, echo)
			midi = glide
	_mix_bus(_note(inst, midi, length, glide if sustained else -1), t, vel, verb, echo)


func _mix_bus(x: PackedFloat32Array, t: float, vel: float, verb: float, echo: float) -> void:
	var offset := _seconds(maxf(t, 0.0))
	_mix_wrap(_dry, x, offset, vel)
	if verb > 0.0:
		_mix_wrap(_verb, x, offset, vel * verb)
	if echo > 0.0:
		_mix_wrap(_echo, x, offset, vel * echo)


## A rendered note, cached by everything that shapes it.
func _note(inst: String, midi: float, length: float, glide: int) -> PackedFloat32Array:
	var key := "%s %s %.3f %d" % [inst, midi, length if inst in ["shinobue", "slidewhistle"] else 0.0, glide]
	if not _cache.has(key):
		_cache[key] = _render(inst, _freq(midi), length, _freq(glide) if glide >= 0 else 0.0)
	return _cache[key]


func _render(inst: String, f: float, length: float, glide: float) -> PackedFloat32Array:
	match inst:
		"marimba":
			return _marimba(f)
		"xylophone":
			return _xylophone(f, 0.0)
		"xylo_detuned":
			return _xylophone(f, 0.022)
		"woodblock":
			return _block(f, [1.0, 2.71, 4.4], [0.05, 0.02, 0.01], 0.0)
		"templeblock":
			return _block(f * 0.5, [1.0, 2.2, 3.6], [0.12, 0.04, 0.015], 0.03)
		"logdrum":
			return _logdrum(f)
		"hyoshigi":
			return _hyoshigi()
		"binzasara":
			return _binzasara()
		"belly":
			return _belly(f)
		"taiko":
			return _taiko()
		"ka":
			return _block(1400.0, [1.0, 1.62, 2.9], [0.03, 0.02, 0.008], 0.0)
		"shamisen":
			return _shamisen(f)
		"shinobue":
			return _shinobue(f, length, glide)
		"slidewhistle":
			return _slide_whistle(f, glide, length)
		"mukkuri":
			return _mukkuri(f)
		"creak":
			return _creak()
		"doorknock":
			return _door_knock(false)
		"doorknock_far":
			return _door_knock(true)
	push_error("unknown instrument " + inst)
	return PackedFloat32Array()


# --- Instruments --------------------------------------------------------------------------


## A rosewood bar over a tuned tube: the fundamental rings longest, the bar's own
## overtones (near the 4th and 10th harmonic) die fast, and a soft yarn mallet thuds.
## Lower bars ring longer.
func _marimba(f: float) -> PackedFloat32Array:
	var d := clampf(0.7 * sqrt(220.0 / f), 0.18, 1.3)
	var out := _partials(d * 3.0, f, [1.0, 3.93, 9.2], [1.0, 0.22, 0.05], [d, d * 0.22, d * 0.06], 0.0)
	_mix(out, _shape(_bandpass(_noise(0.02), minf(f * 2.0, 4000.0), 1.0), 0.0005, 0.004), 0, 0.25)
	return out


## A harder, drier bar struck with a hard mallet; `detune` mixes in a copy that far
## (as a ratio) off pitch, which makes it beat and sound slightly broken.
func _xylophone(f: float, detune: float) -> PackedFloat32Array:
	var d := clampf(0.3 * sqrt(440.0 / f), 0.07, 0.45)
	var out := _partials(d * 3.0, f, [1.0, 3.0, 6.1], [1.0, 0.3, 0.08], [d, d * 0.3, d * 0.12], 0.0)
	if detune > 0.0:
		_mix(out, _partials(d * 3.0, f * (1.0 + detune), [1.0, 3.0], [0.8, 0.2], [d * 1.3, d * 0.3], 0.0), 0, 0.8)
	_mix(out, _shape(_bandpass(_noise(0.01), 3500.0, 1.2), 0.0002, 0.002), 0, 0.5)
	return out


## A hollow block: a few short modes, a click, and a slight drop in pitch as it is hit.
func _block(f: float, ratios: Array, decays: Array, drop: float) -> PackedFloat32Array:
	var out := _partials(decays[0] * 5.0, f, ratios, [1.0, 0.5, 0.25], decays, drop)
	_mix(out, _shape(_bandpass(_noise(0.01), f * 1.5, 1.5), 0.0002, 0.003), 0, 0.4)
	return out


## A slit log drum: a deep tongue of wood that bends down in pitch as it settles, and
## the thud of the beater on the log.
func _logdrum(f: float) -> PackedFloat32Array:
	var out := _partials(1.6, f, [1.0, 2.45, 4.1], [1.0, 0.4, 0.15], [0.45, 0.12, 0.04], 0.06)
	_mix(out, _shape(_lowpass(_noise(0.08), 500.0, 0.8), 0.001, 0.02), 0, 0.6)
	return out


## Hyoshigi: two hardwood clappers struck together, a bright ringing "kaan".
func _hyoshigi() -> PackedFloat32Array:
	var out := _partials(0.4, 2150.0, [1.0, 1.56, 2.43], [1.0, 0.6, 0.3], [0.09, 0.05, 0.03], 0.0)
	_mix(out, _shape(_bandpass(_noise(0.02), 4000.0, 1.0), 0.0002, 0.003), 0, 0.8)
	return out


## Binzasara: a string of wooden slats shaken together, a dry little rattle.
func _binzasara() -> PackedFloat32Array:
	var out := _silence(0.08)
	for k in 4:
		var clack := _shape(_bandpass(_noise(0.02), rng.randf_range(2500.0, 4200.0), 3.0), 0.0005, 0.006)
		_mix(out, clack, _seconds(k * rng.randf_range(0.006, 0.012)), 1.0 - k * 0.2)
	return out


## A tanuki drumming its belly: a round "pon" that drops a little in pitch, with the
## soft slap of a paw.
func _belly(f: float) -> PackedFloat32Array:
	var n := _seconds(0.7)
	var out := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * f * (1.0 + 0.4 * exp(-t / 0.025)) / RATE
		out[i] = (sin(phase) + 0.15 * sin(2.0 * phase)) * exp(-t / 0.17) * minf(1.0, t / 0.002)
	_mix(out, _shape(_lowpass(_noise(0.03), 900.0, 0.7), 0.001, 0.008), 0, 0.5)
	return out


## Taiko: a cowhide head on a hollowed trunk, a deep boom that sags in pitch.
func _taiko() -> PackedFloat32Array:
	var out := _partials(1.4, 62.0, [1.0, 1.58, 2.2], [1.0, 0.4, 0.2], [0.4, 0.12, 0.06], 0.25)
	_mix(out, _shape(_lowpass(_noise(0.1), 300.0, 0.8), 0.001, 0.035), 0, 1.0)
	_mix(out, _shape(_bandpass(_noise(0.02), 1200.0, 1.0), 0.0005, 0.004), 0, 0.2)
	return out


## Shamisen: a plucked silk string (Karplus-Strong) on a skin-and-wood box. The buzz of
## the sawari comes from softly clipping the string's motion.
func _shamisen(f: float) -> PackedFloat32Array:
	var n := _seconds(0.7)
	var period := float(RATE) / f
	var size := int(period) + 2
	var line := _noise(float(size) / RATE)
	var out := _silence_samples(n)
	var pos := 0
	for i in n:
		var read := fposmod(pos - period, size)
		var a := int(read)
		var frac := read - a
		var v := lerpf(line[a], line[(a + 1) % size], frac)
		var nv := lerpf(line[(a + 1) % size], line[(a + 2) % size], frac)
		var y := (v + nv) * 0.5 * 0.993
		line[pos % size] = y
		pos = (pos + 1) % size
		out[i] = tanh(y * 2.5) * 0.6 + y * 0.4
	return _highpass(_shape(out, 0.0005, 0.18), 120.0, 0.7)


## Shinobue: a shrill bamboo festival flute. Each note scoops up into pitch from a
## semitone under, as a player's fingers lift off a hole, wavers once it is held, and
## carries a lot of breath. With `glide` the note slides there over its second half.
func _shinobue(f: float, length: float, glide: float) -> PackedFloat32Array:
	var n := _seconds(length + 0.09)
	var breath := _bandpass(_noise(length + 0.09), f, 6.0)
	var air := _highpass(_noise(length + 0.09), 2500.0, 0.7)
	var out := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var target := f
		if glide > 0.0 and t > length * 0.45:
			target = f * pow(glide / f, clampf((t - length * 0.45) / (length * 0.4), 0.0, 1.0))
		var scoop := pow(2.0, -exp(-t / 0.018) / 12.0)
		var vibrato := 1.0 + 0.007 * sin(TAU * 5.6 * t) * clampf((t - 0.22) / 0.3, 0.0, 1.0)
		phase += TAU * target * scoop * vibrato / RATE
		var env := minf(1.0, t / 0.025) * clampf((length + 0.06 - t) / 0.06, 0.0, 1.0)
		var tone := sin(phase) + 0.3 * sin(2.0 * phase) + 0.12 * sin(3.0 * phase) + 0.04 * sin(4.0 * phase)
		var chiff := exp(-t / 0.02)
		out[i] = env * (tone * 0.8 + breath[i] * 1.5 + air[i] * (0.05 + 0.25 * chiff))
	return out


## A slide whistle swooping from `from` up to `to` over `length`: the comic swell.
func _slide_whistle(from: float, to: float, length: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var air := _highpass(_noise(length), 3000.0, 0.7)
	var out := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := pow(t / length, 1.6)
		phase += TAU * from * pow(to / from, k) * (1.0 + 0.012 * sin(TAU * 6.5 * t)) / RATE
		var env := minf(1.0, t / 0.05) * minf(1.0, (length - t) / 0.04) * (0.5 + 0.5 * k)
		out[i] = env * (sin(phase) + 0.08 * sin(2.0 * phase) + air[i] * 0.08)
	return out


## Mukkuri: a bamboo jaw harp. A buzzing reed at `f`, and the mouth around it opening
## and closing, which sweeps a resonance up and back down: "boiyoing".
func _mukkuri(f: float) -> PackedFloat32Array:
	var length := 0.7
	var n := _seconds(length)
	var reed := _silence_samples(n)
	var phase := 0.0
	for i in n:
		phase = fposmod(phase + f / RATE, 1.0)
		reed[i] = 1.0 if phase < 0.12 else -0.14
	var freqs := PackedFloat32Array()
	freqs.resize(n)
	for i in n:
		var t := float(i) / RATE
		freqs[i] = 350.0 + 1300.0 * pow(sin(PI * minf(t / 0.45, 1.0)), 2.0)
	var out := _filter_swept(reed, "bandpass", freqs, 7.0)
	_mix(out, _partials(length, f, [1.0], [0.3], [0.3], 0.0), 0, 1.0)
	return _shape(out, 0.004, 0.25)


## An old board creaking under a weight: stick-slip, a stuttering train of tiny impulses
## whose rate wanders, each ringing the wood's resonances.
func _creak() -> PackedFloat32Array:
	var length := 1.4
	var n := _seconds(length)
	var pulses := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var rate := 38.0 + 30.0 * sin(TAU * 0.9 * t + 1.0) + 14.0 * sin(TAU * 3.1 * t)
		phase += rate / RATE
		if phase >= 1.0:
			phase -= 1.0
			pulses[i] = rng.randf_range(0.6, 1.0)
	var out := _bandpass(pulses, 650.0, 12.0)
	_mix(out, _bandpass(pulses, 1450.0, 14.0), 0, 0.7)
	_mix(out, _bandpass(pulses, 2600.0, 10.0), 0, 0.3)
	var env := _ramp(n, 0.25, 0.4)
	for i in n:
		out[i] *= env[i] * 3.0
	return out


## A knuckle on a hollow wooden door. `far` makes it a door somewhere out in the trees:
## duller and darker.
func _door_knock(far: bool) -> PackedFloat32Array:
	var out := _partials(0.4, 118.0, [1.0, 1.6, 2.3, 3.9], [1.0, 0.7, 0.5, 0.2], [0.07, 0.05, 0.035, 0.02], 0.02)
	_mix(out, _shape(_lowpass(_noise(0.05), 700.0, 0.8), 0.0005, 0.012), 0, 0.8)
	_mix(out, _shape(_bandpass(_noise(0.01), 2200.0, 1.5), 0.0002, 0.002), 0, 0.3)
	return _lowpass(out, 900.0, 0.7) if far else out


# --- Synthesis ----------------------------------------------------------------------------


## Modal synthesis: a sum of exponentially decaying sines at `ratios` of `f`, each with
## its own amplitude and decay; `drop` bends the whole thing down by that fraction
## during the first few milliseconds, as a struck body does.
func _partials(length: float, f: float, ratios: Array, amps: Array, decays: Array, drop: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var out := _silence_samples(n)
	for m in ratios.size():
		var freq: float = f * ratios[m]
		if freq >= RATE * 0.45:
			continue
		var amp: float = amps[m]
		var decay: float = decays[m]
		var phase := rng.randf() * TAU
		for i in n:
			var t := float(i) / RATE
			var e := exp(-t / decay)
			if e < 0.0005:
				break
			phase += TAU * freq * (1.0 + drop * exp(-t / 0.03)) / RATE
			out[i] += sin(phase) * e * amp * minf(1.0, t / 0.0006)
	return out


## Schroeder reverb: four damped combs in parallel into two allpasses. On a looping cue
## the input is run twice and the second pass kept, so the tail of the end of the loop
## already rings into its start.
func _reverb(x: PackedFloat32Array, time: float, damp: float) -> PackedFloat32Array:
	var input := x.duplicate()
	if _loop:
		input.append_array(x)
	var wet := _silence_samples(input.size())
	for delay in [778, 808, 745, 711]:
		var g := pow(0.001, float(delay) / (time * RATE))
		var buf := _silence_samples(delay)
		var lp := 0.0
		for i in input.size():
			var y := buf[i % delay]
			lp = y * (1.0 - damp) + lp * damp
			buf[i % delay] = input[i] + lp * g
			wet[i] += y * 0.25
	for delay in [112, 278]:
		var buf := _silence_samples(delay)
		for i in wet.size():
			var b := buf[i % delay]
			var v := wet[i] + b * 0.5
			buf[i % delay] = v
			wet[i] = b - v * 0.5
	return wet.slice(x.size()) if _loop else wet


## A tape-ish echo: repeats every `delay` seconds, each `feedback` as loud and darker.
func _delay(x: PackedFloat32Array, delay: float, feedback: float) -> PackedFloat32Array:
	var input := x.duplicate()
	if _loop:
		input.append_array(x)
	var d := _seconds(delay)
	var out := _silence_samples(input.size())
	var lp := 0.0
	for i in input.size():
		var back := out[i - d] if i >= d else 0.0
		lp = lp * 0.5 + back * 0.5
		out[i] = input[i] + lp * feedback
	for i in input.size():
		out[i] -= input[i]
	return out.slice(x.size()) if _loop else out


func _noise(length: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## An attack ramp of `attack` seconds, then an exponential decay with time constant
## `decay` seconds.
func _shape(x: PackedFloat32Array, attack: float, decay: float) -> PackedFloat32Array:
	var out := x.duplicate()
	for i in out.size():
		var t := float(i) / RATE
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


## An RBJ biquad whose frequency may change every sample (same as in synth_sfx.gd).
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
			var w0 := TAU * clampf(freqs[i], 20.0, RATE * 0.45) / RATE
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


## Mixes into a bus; on a looping cue whatever runs past the end comes back in at the
## start.
func _mix_wrap(into: PackedFloat32Array, x: PackedFloat32Array, offset: int, gain: float) -> void:
	if not _loop:
		_mix(into, x, offset, gain)
		return
	var n := into.size()
	for i in x.size():
		into[(offset + i) % n] += x[i] * gain


func _silence(length: float) -> PackedFloat32Array:
	return _silence_samples(_seconds(length))


func _silence_samples(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	return out


func _seconds(length: float) -> int:
	return int(round(length * RATE))


func _midi(name: String) -> int:
	var semis := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var note: int = semis[name[0]]
	var rest := name.substr(1)
	if rest.begins_with("b"):
		note -= 1
		rest = rest.substr(1)
	elif rest.begins_with("#"):
		note += 1
		rest = rest.substr(1)
	return 12 * (int(rest) + 1) + note


func _mapped(midi: int, pitch_map: Dictionary) -> int:
	return midi + int(pitch_map.get(midi % 12, 0))


func _freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


# --- Output -------------------------------------------------------------------------------


## Sums the buses through the reverb (`wet` of it) and, if anything was sent there, the
## echo; squeezes the peaks a little, normalises and writes the cue.
func _finish(cue: String, wet: float, room := 1.6) -> void:
	var out := _dry.duplicate()
	var verb := _reverb(_verb, room, 0.35)
	var echo_used := false
	for v in _echo:
		if v != 0.0:
			echo_used = true
			break
	var echo := _delay(_echo, _step * 6.0, 0.45) if echo_used else PackedFloat32Array()
	for i in out.size():
		out[i] += verb[i] * wet * 4.0
		if echo_used:
			out[i] += echo[i] * 0.6
	out = _softclip(out, 1.3)
	var top := 0.0
	for v in out:
		top = maxf(top, absf(v))
	for i in out.size():
		out[i] *= 0.84 / top
	if not _loop:
		var fade := _seconds(0.5)
		for i in fade:
			out[out.size() - 1 - i] *= float(i) / fade
	_write(cue, out)
	_cache.clear()


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


## Writes a 16-bit mono WAV to user://music_render and encodes it to OGG Vorbis in the
## concepts folder with ffmpeg; without ffmpeg the WAV stays where it is.
func _write(cue: String, x: PackedFloat32Array) -> void:
	var wav := ProjectSettings.globalize_path("user://music_render/%s.wav" % cue)
	DirAccess.make_dir_recursive_absolute(wav.get_base_dir())
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, clampi(int(round(x[i] * 32767.0)), -32768, 32767))
	var file := FileAccess.open(wav, FileAccess.WRITE)
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
	var ogg := ProjectSettings.globalize_path(ROOT + cue + ".ogg")
	DirAccess.make_dir_recursive_absolute(ogg.get_base_dir())
	var output := []
	var code := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg], output, true)
	if code != 0:
		push_warning("ffmpeg failed (%d), left the WAV at %s: %s" % [code, wav, "".join(output)])
