extends SceneTree

## Renders the music concept sketches in assets/audio/music/concepts from code: the wood
## leitmotif and the cues built on it. There are seven sets: round 1 (`r1`, the festival
## take, in concepts/: leitmotif, village, outside the village at night); three softer,
## woodier round-2 versions of those in concepts/v2/: `a` the lullaby (soft mallets), `b`
## the workshop (wooden percussion forward) and `c` the forest night (airy and sparse); and
## three round-3 takes in concepts/v3/ with only an outside cue and a combat cue each: `d`
## the bowed hollow, `e` the clockwork wood and `f` under the floorboards (see Round 3).
##
##   godot --headless --path cutting-board -s res://tools/audio/synth_music.gd
##   godot --headless --path cutting-board -s res://tools/audio/synth_music.gd -- --set=a,b --only=village
##   godot --headless --path cutting-board -s res://tools/audio/synth_music.gd -- --set=d --mute=bowed,bowedpair
##
## then `godot --headless --path cutting-board --import` to reimport. Needs ffmpeg on the
## PATH to write OGG Vorbis; without it the WAVs are left in user://music_render instead.
## Round 3 needs it for its reverb too. `--mute` leaves instruments out, for balancing.
##
## Every instrument is made of wood (or at least sounds it): marimba and xylophone bars as
## sums of decaying inharmonic sines, wood and temple blocks, a slit log drum, hyoshigi
## clappers, binzasara bead rattles, a tanuki belly drum, taiko, a plucked shamisen
## (Karplus-Strong), a shinobue bamboo flute, a mukkuri bamboo jaw harp, a creaking
## board and a knocked door. Round 2 adds softer, rounder wood: a rubber-mallet marimba, a
## kalimba on a wooden box, a balafon with its gourd, a wooden tongue drum, felt-muffled
## blocks, a seed shaker, bamboo wind chimes, a wooden frog and a breathy low flute, most
## of them coloured by the resonances of a wooden body (see _wood_body). Round 3 adds bowed
## wooden bars, a breathy bass flute, a hollow log blown like a didgeridoo, a paired bass
## marimba, big slit drums, bark scrapes, seed-pod rattles, groaning beams, woodpeckers
## and falling seeds. No recorded audio. Rounds 1 and 2 are lo-fi on purpose like
## synth_sfx.gd, mono 22 050 Hz with a small Schroeder reverb that nods to the PS1 SPU's;
## round 3 is 44.1 kHz stereo with a long convolution hall (see _finish_hifi).
##
## The scores are plain text, one token per note: `D5:2` is D5 for two sixteenths, `r:4`
## a rest, `Ab4/A4:4` a note that slides (or, on a struck bar, grace-notes) into another,
## a trailing `!` an accent and `|` a bar line. The leitmotif is MOTIF below; the cues
## quote it whole, transpose it, stretch it, flatten its fifth or play only some of its
## bars. Drum parts are sixteen-step patterns: `x` hit, `X` accent, `o` ghost, `.` rest.
## Round 3 mostly places its notes by step from the start of the loop instead (see
## _line_at), in 5/4, 7/8 and 12/8 as well as 4/4.
##
## The cues loop: every note and the reverb and echo tails are wrapped around the loop
## end onto its start, so the file loops without a seam or a crossfade.

const ROOT := "res://assets/audio/music/concepts/"

## The leitmotif, in D min'yo (D F G A C): a double knock on wood, a cheeky leap up,
## a tumble down; then the same knock higher, and a wrong-footed slide from Ab into A
## before the bottom drops out onto a low D.
const MOTIF := "D5:2 D5:2 r:2 A5:4 G5:2 F5:2 G5:2 | D5:6 C5:2 A4:4 r:4 | D5:2 D5:2 r:2 A5:4 C6:2 A5:2 G5:2 | F5:2 D5:2 C5:2 Ab4/A4:4 r:2 D4:4!"
## The bass roots under the motif, one per bar.
const ROOTS := [50, 50, 48, 45]

## Instruments that are blown, not struck: they hold for the note's length and can slide.
const SUSTAINED := ["shinobue", "slidewhistle", "flute", "bowed", "bowedpair", "breathflute", "hollowlog", "scrape", "rattle", "groan"]
## Round 3's faders: every hit on these instruments is scaled by this much, which keeps the
## drones and drums from swamping the small wooden sounds in all six cues at once.
const R3_MIX := {
	"bowed": 0.4, "bowedpair": 0.4, "hollowlog": 0.45, "thump": 0.45, "slit": 0.5, "tongue": 0.6,
	"lowmarimba": 0.8, "tick": 1.8, "knock": 0.7, "knockfar": 0.9, "scrape": 2.2, "rattle": 2.8,
	"groan": 2.0, "seedfall": 1.6, "balafon": 1.3, "breathflute": 1.3,
}
## The voices that carry notes rather than knocks, whose range the log reports (round 3
## keeps them low).
const MELODIC := ["marimba", "xylophone", "xylo_detuned", "shinobue", "shamisen", "softmarimba", "kalimba", "balafon", "tongue", "flute", "bowed", "bowedpair", "breathflute", "lowmarimba", "hollowlog"]

var rng := RandomNumberGenerator.new()

## Samples per second: 22 050 mono for the lo-fi rounds 1 and 2, 44 100 stereo for round 3.
var _rate := 22050
var _stereo := false

## The file the cue being rendered is written to, relative to ROOT and without extension.
var _name := ""
## The master: reverb damping (higher is darker), a final low-pass (0 for none), how hard
## the peaks are squeezed and the peak level the cue is normalised to.
var _damp := 0.35
var _master_lp := 0.0
var _drive := 1.3
var _level := 0.84
## The buses a cue is mixed into: dry, the reverb send and the echo send; in stereo these
## are the left channels and the `_r` ones the right.
var _dry := PackedFloat32Array()
var _verb := PackedFloat32Array()
var _echo := PackedFloat32Array()
var _dry_r := PackedFloat32Array()
var _verb_r := PackedFloat32Array()
var _echo_r := PackedFloat32Array()
## In stereo: where each instrument stands, -1 (left) to 1 (right), and how far a hit may
## stray from there.
var _pans := {}
var _pan_spread := 0.0
## Whether notes past the end wrap around to the start.
var _loop := false
## Seconds per step (a sixteenth, unless a cue says otherwise) and steps per bar.
var _step := 0.125
var _meter := 16
## The lowest and highest note played on a MELODIC voice in the cue, in MIDI.
var _range := Vector2(INF, -INF)
var _cache := {}
## Instruments left out of the mix (`--mute=`), for listening to the rest while balancing.
var _muted: PackedStringArray = []


func _init() -> void:
	var only: PackedStringArray = []
	var only_sets: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--set="):
			only_sets = arg.trim_prefix("--set=").split(",")
		elif arg.begins_with("--mute="):
			_muted = arg.trim_prefix("--mute=").split(",")
	var sets := {
		"r1": {"leitmotif": _make_leitmotif, "village": _make_village, "outside": _make_outside},
		"a": {"leitmotif": _make_a_leitmotif, "village": _make_a_village, "outside": _make_a_outside},
		"b": {"leitmotif": _make_b_leitmotif, "village": _make_b_village, "outside": _make_b_outside},
		"c": {"leitmotif": _make_c_leitmotif, "village": _make_c_village, "outside": _make_c_outside},
		"d": {"outside": _make_d_outside, "combat": _make_d_combat},
		"e": {"outside": _make_e_outside, "combat": _make_e_combat},
		"f": {"outside": _make_f_outside, "combat": _make_f_combat},
	}
	for version in sets:
		if not only_sets.is_empty() and not only_sets.has(version):
			continue
		var cues: Dictionary = sets[version]
		var round3: bool = version in ["d", "e", "f"]
		_rate = 44100 if round3 else 22050
		_stereo = round3
		for cue in cues:
			if not only.is_empty() and not only.has(cue):
				continue
			_name = cue if version == "r1" else "%s/%s_%s" % ["v3" if round3 else "v2", version, cue]
			rng.seed = hash(cue if version == "r1" else _name)
			_range = Vector2(INF, -INF)
			var started := Time.get_ticks_msec()
			(cues[cue] as Callable).call()
			var notes := ""
			if _range.x <= _range.y:
				notes = ", melodic voices %s-%s (%.0f-%.0f Hz)" % [_note_name(_range.x), _note_name(_range.y), _freq(_range.x), _freq(_range.y)]
			print("%s  (%d ms%s)" % [_name, Time.get_ticks_msec() - started, notes])
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
	_finish(0.18)


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
	_finish(0.16)


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
	_finish(0.3, 0.42)


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


# --- Round 2, A: the lullaby --------------------------------------------------------------
# Soft rubber-mallet marimba and a kalimba on a wooden box, a breathy low flute, a seed
# shaker and wooden wind chimes. Slow and rocking; the only jokes left are the slide in
# bar 4 of the motif and a soft bonk on a muffled log drum.

## Two soft knocks, the motif on the kalimba over a marimba bass, then on the marimba with
## the flute an octave down and the kalimba picking the chords; a soft bonk to end.
func _make_a_leitmotif() -> void:
	_begin(80.0, 10, false, 3.0)
	_warm(0.6, 5500.0)
	_hit("feltblock", 74, 4, 0.5, 0.3)
	_hit("feltblock", 74, 6, 0.45, 0.3)
	_hit("softmarimba", 38, 8, 0.5, 0.3)
	_line("kalimba", 1, MOTIF, 0.8, 0.3)
	for bar in range(1, 9):
		var root: int = ROOTS[(bar - 1) % 4]
		_hit("softmarimba", root - 12, bar * 16, 0.7, 0.25)
		_hit("softmarimba", root - 5, bar * 16 + 8, 0.45, 0.25)
	_pattern("shaker", 1, 8, "....x.......x...", 0, 0.25, 0.1)
	_line("softmarimba", 5, MOTIF, 0.75, 0.3)
	_line("flute", 5, MOTIF, 0.45, 0.4, -12)
	_kalimba_picking(5, 4, [50, 48, 45, 50], 0.22)
	_hit("softlog", 38, 9 * 16, 0.8, 0.4)
	_hit("softmarimba", 38, 9 * 16, 0.6, 0.4)
	_hit("softmarimba", 50, 9 * 16 + 1, 0.4, 0.4)
	_chimes(9, 1, 1.0, 0.3)
	_finish(0.25, 2.4)


## The village as a lullaby, 84 BPM, 16 bars. A rocking bass and the kalimba picking
## under it all; the motif on marimba, then on the flute; then the marimba and the kalimba
## trade its halves, and the tumble lands on a soft bonk.
func _make_a_village() -> void:
	_begin(84.0, 16, true)
	_warm(0.6, 5500.0)
	for bar in 16:
		var root: int = ROOTS[bar % 4]
		_hit("softmarimba", root - 12, bar * 16, 0.6, 0.2)
		_hit("softmarimba", root - 5, bar * 16 + 6, 0.4, 0.2)
		_hit("softmarimba", root - 12, bar * 16 + 10, 0.35, 0.2)
		_pattern("feltblock", bar, 1, "....x.......x...", 76, 0.3, 0.15)
		_pattern("shaker", bar, 1, "..x...x...x...x.", 0, 0.18, 0.05)
	_kalimba_picking(0, 8, ROOTS, 0.22)
	_kalimba_picking(12, 4, ROOTS, 0.16)
	_line("softmarimba", 4, MOTIF, 0.8, 0.25)
	_line("flute", 8, MOTIF, 0.6, 0.4, -12)
	_line("kalimba", 8, MOTIF, 0.3, 0.3)
	var bars := MOTIF.split("|")
	_line("softmarimba", 12, bars[0], 0.8, 0.25)
	_line("kalimba", 13, bars[0], 0.55, 0.35)
	_line("softmarimba", 14, bars[2], 0.8, 0.25)
	_line("kalimba", 15, bars[3], 0.6, 0.3)
	_hit("softlog", 38, 15 * 16 + 12, 0.6, 0.35)
	_chimes(3, 1, 1.0, 0.25)
	_chimes(7, 1, 1.0, 0.25)
	_chimes(11, 1, 1.0, 0.25)
	_finish(0.22, 2.4)


## Outside as a lullaby at night, 60 BPM, 12 bars: a soft marimba roll whose fifth sags,
## a muffled log drum far off, the kalimba picking out the motif at half speed (out of
## tune, then in), a far knock that the woods answer, and wind chimes.
func _make_a_outside() -> void:
	_begin(60.0, 12, true)
	_warm(0.65, 4800.0)
	var bars := MOTIF.split("|")
	var tops := [57, 57, 56, 57, 56, 57]
	for bar in 12:
		var swell := 0.75 + 0.25 * sin(TAU * bar / 6.0)
		_roll(bar, 50, tops[int(bar / 2.0)], 0.13 * swell, 0.45)
		if bar % 2 == 0:
			_hit("softlog", 38, bar * 16, 0.5, 0.4, 2.0, -1, 0.4)
	_line("kalimba", 2, bars[0] + "|" + bars[1], 0.55, 0.5, 0, 2.0, {9: -1})
	_line("kalimba", 6, bars[2] + "|" + bars[3], 0.55, 0.5, 0, 2.0)
	_line("flute", 6, bars[2] + "|" + bars[3], 0.22, 0.6, -12, 2.0)
	_knocks(10, [0, 3], 0.45, true)
	_knocks(11, [4, 7, 13], 0.3, true)
	_chimes(0, 2, 0.8, 0.22)
	_chimes(10, 2, 0.8, 0.22)
	_finish(0.28, 2.6)


# --- Round 2, B: the workshop -------------------------------------------------------------
# Woody percussion up front, all of it muffled: a balafon and a wooden tongue drum carry
# the motif, a slit log drum and felt-wrapped blocks keep the groove, a seed shaker
# whispers, a board creaks and, once per cue, a lowpassed jaw harp boings under the bonk.


## Knock knock, knock knock, and the tongue drum counts in; the motif on balafon over the
## groove, then on the tongue drum with the balafon an octave down; a bonk and a boing.
func _make_b_leitmotif() -> void:
	_begin(92.0, 10, false, 2.5)
	_warm(0.5, 6000.0)
	_pattern("feltblock", 0, 1, "x.x.....x.x.....", 72, 0.6, 0.2)
	_pattern("tongue", 0, 1, "............x.x.", 50, 0.4, 0.2)
	_line("balafon", 1, MOTIF, 0.85, 0.2)
	for bar in range(1, 9):
		var root: int = ROOTS[(bar - 1) % 4]
		_hit("tongue", root - 12, bar * 16, 0.8, 0.15)
		_hit("tongue", root - 5, bar * 16 + 8, 0.5, 0.15)
		_pattern("feltblock", bar, 1, "....x.......x...", 76, 0.4, 0.1)
		_pattern("shaker", bar, 1, "x.o.x.o.x.o.x.oo", 0, 0.2, 0.05)
	_line("tongue", 5, MOTIF, 0.7, 0.2)
	_line("balafon", 5, MOTIF, 0.5, 0.2, -12)
	_pattern("softlog", 5, 4, "x.....x...x.....", 38, 0.55, 0.2)
	_hit("softcreak", 0, 7 * 16 + 8, 0.35, 0.4)
	_hit("softlog", 38, 9 * 16, 0.9, 0.35)
	_hit("softmukkuri", 38, 9 * 16 + 2, 0.4, 0.35)
	_finish(0.18, 1.8)


## The village as a workshop, 96 BPM, 20 bars. The groove: tongue drum bass, felt blocks
## on the backbeat, the shaker, a knock-knock fill on felt temple blocks every other bar.
## The motif on balafon; on tongue drum; traded between balafon and temple blocks with a
## bonk and a boing; then on both with the slit drum.
func _make_b_village() -> void:
	_begin(96.0, 20, true)
	_warm(0.5, 6000.0)
	for bar in 20:
		var root: int = ROOTS[bar % 4]
		_hit("tongue", root - 12, bar * 16, 0.75, 0.15)
		_hit("tongue", root - 12, bar * 16 + 6, 0.45, 0.15)
		_hit("tongue", root - 5, bar * 16 + 8, 0.5, 0.15)
		_pattern("feltblock", bar, 1, "....x.......x...", 76, 0.38, 0.1)
		_pattern("shaker", bar, 1, "x.o.x.o.x.o.x.oo", 0, 0.18, 0.05)
		if bar % 2 == 1 and bar != 15:
			_pattern("felttemple", bar, 1, "...........x.x..", 74, 0.3, 0.2)
	_line("balafon", 4, MOTIF, 0.85, 0.2)
	_line("tongue", 8, MOTIF, 0.75, 0.2)
	_line("balafon", 8, MOTIF, 0.45, 0.15, -12)
	var bars := MOTIF.split("|")
	_line("balafon", 12, bars[0], 0.85, 0.2)
	_line("felttemple", 13, "D5:2 D5:2 r:2 A5:4 G5:2 F5:2 G5:2", 0.6, 0.25)
	_line("balafon", 14, bars[2], 0.85, 0.2)
	_line("tongue", 15, bars[3], 0.75, 0.2)
	_hit("softlog", 38, 15 * 16 + 12, 0.85, 0.3)
	_hit("softmukkuri", 38, 15 * 16 + 13, 0.35, 0.3)
	_line("balafon", 16, MOTIF, 0.75, 0.2)
	_line("tongue", 16, MOTIF, 0.5, 0.2, -12)
	_pattern("softlog", 16, 4, "x.....x...x.....", 38, 0.45, 0.2)
	_finish(0.16, 1.8)


## The workshop yard at night, 72 BPM, 14 bars: the slit drum a slow heartbeat with an
## echo, the shaker ticking like insects, the balafon picking at the motif with its fifth
## sagging, knocks that the woods answer, a creak, and the tongue drum humming the knock
## at half speed.
func _make_b_outside() -> void:
	_begin(72.0, 14, true)
	_warm(0.6, 5000.0)
	var bars := MOTIF.split("|")
	for bar in 14:
		_hit("softlog", 38, bar * 16, 0.7, 0.3, 2.0, -1, 0.45)
		if bar % 2 == 1:
			_hit("softlog", 45, bar * 16 + 10, 0.35, 0.3, 2.0, -1, 0.45)
		_hit("tongue", 38 if bar % 4 < 2 else 36, bar * 16 + 8, 0.3, 0.35)
		_pattern("shaker", bar, 1, "..o...o.....o..." if bar % 2 == 0 else "......o...o.o...", 0, 0.3, 0.2)
	_line("balafon", 2, bars[0] + "|" + bars[1], 0.6, 0.45, 0, 1.0, {9: -1})
	_line("balafon", 6, bars[2] + "|" + bars[3], 0.6, 0.45, -12)
	_hit("softmukkuri", 38, 7 * 16 + 12, 0.3, 0.4)
	_knocks(4, [0, 3], 0.6, false)
	_knocks(5, [4, 7], 0.4, true)
	_hit("softcreak", 0, 9 * 16 + 4, 0.4, 0.45)
	_line("tongue", 10, bars[0], 0.5, 0.5, -12, 2.0)
	_knocks(12, [0, 3], 0.6, false)
	_knocks(13, [2, 5, 13], 0.4, true)
	_finish(0.25, 2.2)


# --- Round 2, C: the forest night ---------------------------------------------------------
# Airy and sparse: wind in the leaves, bamboo wind chimes, a breathy low flute far off,
# a soft marimba roll for a pad, a wooden tongue drum like a slow pulse. The wink is a
# carved wooden frog croaking now and then.


## Wind and chimes, the motif once on the low flute over a marimba pad, the woods knocking
## the first two notes back on bamboo; a far bonk with an echo, and a frog.
func _make_c_leitmotif() -> void:
	_begin(66.0, 6, false, 4.0)
	_warm(0.7, 4800.0)
	_air(0.08, 1)
	for bar in 6:
		var root: int = 50 if bar == 0 or bar == 5 else ROOTS[(bar - 1) % 4]
		_roll(bar, root - 12, root - 5, 0.12, 0.5)
	_chimes(0, 1, 1.0, 0.3)
	_line("flute", 1, MOTIF, 0.7, 0.55, -12)
	_line("bamboo", 2, "D5:2 D5:2 r:12", 0.35, 0.5)
	_line("bamboo", 4, "r:8 D5:2 D5:2 r:4", 0.3, 0.5)
	_hit("softlog", 38, 5 * 16, 0.7, 0.5, 2.0, -1, 0.5)
	_hit("woodfrog", 0, 5 * 16 + 6, 0.35, 0.4)
	_chimes(5, 1, 1.0, 0.25)
	_finish(0.32, 3.0)


## The village at dusk, 72 BPM, 16 bars: a breathing marimba pad on the roots, the tongue
## drum on the downbeats, the kalimba plucking only the knocks of the motif, then the
## flute with the whole of it, then the kalimba alone; chimes and a little wind.
func _make_c_village() -> void:
	_begin(72.0, 16, true)
	_warm(0.7, 4800.0)
	_air(0.05, 2)
	for bar in 16:
		var root: int = ROOTS[bar % 4]
		_roll(bar, root - 12, root - 5, 0.15, 0.45)
		_hit("tongue", root - 12, bar * 16, 0.45, 0.3)
		if bar % 2 == 1:
			_hit("tongue", root - 5, bar * 16 + 10, 0.25, 0.3)
	var bars := MOTIF.split("|")
	_line("kalimba", 2, bars[0], 0.5, 0.45)
	_line("kalimba", 6, bars[2], 0.5, 0.45)
	_line("flute", 8, MOTIF, 0.6, 0.5, -12)
	_line("kalimba", 12, MOTIF, 0.45, 0.45)
	_hit("softlog", 38, 15 * 16 + 12, 0.5, 0.45, 2.0, -1, 0.4)
	_hit("woodfrog", 0, 7 * 16 + 10, 0.25, 0.4)
	for bar in [0, 4, 7, 11, 15]:
		_chimes(bar, 1, 1.0, 0.2)
	_finish(0.3, 2.8)


## Deep in the woods, 54 BPM, 12 bars: gusts of wind that set the chimes going, a soft
## drone whose fifth sags, the flute far away with the motif at half speed and flat, the
## kalimba with its second half in tune, a knock answered by bamboo, frogs, a creak.
func _make_c_outside() -> void:
	_begin(54.0, 12, true)
	_warm(0.75, 4500.0)
	_air(0.1, 3)
	var bars := MOTIF.split("|")
	var tops := [57, 56, 57, 56]
	for bar in 12:
		_roll(bar, 50, tops[int(bar / 3.0)], 0.1, 0.55)
		var gust := pow(0.5 + 0.5 * sin(TAU * 3.0 * bar / 12.0 - PI * 0.5), 2.0)
		_chimes(bar, 1, 0.3 + 0.7 * gust, 0.16 + 0.12 * gust)
		if bar % 4 == 0:
			_hit("softlog", 38, bar * 16, 0.45, 0.5, 2.0, -1, 0.5)
	_line("flute", 2, bars[0] + "|" + bars[1], 0.45, 0.7, -12, 2.0, {9: -1}, 0.3)
	_line("kalimba", 7, bars[2] + "|" + bars[3], 0.35, 0.65, 0, 2.0)
	_knocks(6, [0, 3], 0.4, true)
	_line("bamboo", 6, "r:8 D5:2 D5:2 r:4", 0.3, 0.6)
	_hit("woodfrog", 0, 5 * 16 + 4, 0.3, 0.45)
	_hit("woodfrog", 0, 5 * 16 + 7, 0.22, 0.45)
	_hit("woodfrog", 0, 11 * 16 + 9, 0.28, 0.45)
	_hit("softcreak", 0, 9 * 16 + 2, 0.3, 0.5)
	_finish(0.36, 3.2)


# --- Round 3 ------------------------------------------------------------------------------
# Out of the village, and into a fight, in three takes. Hi-fi now: 44.1 kHz stereo, a long
# convolution hall instead of the PS1-ish reverb, nothing crushed. Weirder and quieter: no
# tune on top, only textures, drones and knocks, with the motif in low, broken pieces
# (nothing melodic above D4, about 294 Hz). The scores are written in steps from the start
# of the loop, since the phrases don't keep to the bar lines.
#
# D, the bowed hollow: bowed wooden bars drone and sag, a bass flute breathes bits of the
#    motif, slit drums thud far off. Both cues in 5/4.
# E, the clockwork wood: dry and close. A hollow log drones like a didgeridoo, woodpeckers
#    and ticks knock in 3 against 5 against 7, a low balafon picks at the motif with
#    tritones. Outside in 5/4, combat in 7/8.
# F, under the floorboards: hardly any notes. Wind through a hollow trunk, beams groaning,
#    a far heartbeat in the rhythm of the knock, breath tones. Outside in a 4/4 that nothing
#    keeps to, combat in 12/8.


## Out of the village, take D: 52 BPM in 5/4, 14 bars (81 s). A bowed D2 that never quite
## stops (the bow changes now and then), a bowed fifth above it that sags to the tritone
## and back, and a ghost a quarter tone above the octave. A slit drum thuds somewhere left
## with an echo. Somebody knocks; the woods answer from the right with one knock too many,
## later from the left and then late, and the third time not at all. A bass flute breathes
## the opening of the motif with its fifth sagging, then its second bar; the low marimba
## knocks back and later tumbles down the end of it. Beams groan, seed pods rattle in the
## wind, seeds drop.
func _make_d_outside() -> void:
	_begin(52.0, 14, true, 0.0, 20)
	_r3_master(0.5)
	_wind(0.01, 3, 90.0, 900.0)
	for k in 4:
		_hit("bowedpair", 38, k * 70, 0.36, 0.5, 75.0, -1, 0.0, -0.15 if k % 2 == 0 else 0.15)
	_hit("bowed", 45, 30, 0.28, 0.6, 50.0, 44, 0.0, 0.35)
	_hit("bowed", 45, 110, 0.24, 0.6, 40.0, -1, 0.0, -0.4)
	_hit("bowed", 44, 180, 0.28, 0.6, 60.0, 45, 0.0, 0.35)
	_hit("bowed", 50.5, 95, 0.1, 0.8, 40.0, -1, 0.0, 0.6)
	_hit("bowed", 50.5, 240, 0.08, 0.8, 30.0, -1, 0.0, -0.6)
	var thuds := [[0, 38], [33, 33], [75, 38], [88, 38], [140, 33], [187, 38], [230, 38], [262, 33]]
	for th in thuds:
		_hit("slit", th[1], th[0], 0.4, 0.6, 2.0, -1, 0.3, -0.45)
	# Knock knock. The woods answer.
	_knock_at([40, 42], 46, 0.55, -0.55, false)
	_knock_at([52, 54, 59], 44, 0.35, 0.7, true)
	_knock_at([160, 162], 46, 0.5, -0.55, false)
	_knock_at([171, 173], 44, 0.3, -0.8, true)
	_knock_at([186], 43, 0.22, 0.85, true)
	_knock_at([240, 242], 46, 0.5, -0.55, false)
	# The motif, low and broken.
	_pans = {"breathflute": 0.3, "lowmarimba": -0.35, "groan": 0.5}
	_hit("breathflute", 50, 60, 0.45, 0.6, 4.0)
	_hit("breathflute", 50, 64, 0.4, 0.6, 4.0)
	_hit("breathflute", 57, 70, 0.45, 0.6, 12.0, 56)
	_hit("lowmarimba", 50, 100, 0.35, 0.5)
	_hit("lowmarimba", 50, 103, 0.3, 0.5)
	_line_at("breathflute", 120, "G3:6 F3:4 G3:4 D3:14 C3:4 A2:12", 0.4, 0.6)
	_line_at("lowmarimba", 200, "F3:4 D3:4 C3:4 Ab2/A2:8 r:4 D2:6!", 0.45, 0.5)
	_hit("slit", 38, 224, 0.45, 0.6, 2.0, -1, 0.3, -0.45)
	_hit("groan", 37, 128, 0.22, 0.6, 30.0)
	_hit("groan", 35, 250, 0.2, 0.6, 24.0, -1, 0.0, -0.6)
	_hit("rattle", 91, 85, 0.12, 0.6, 12.0, -1, 0.0, 0.8)
	_hit("rattle", 89, 205, 0.1, 0.6, 10.0, -1, 0.0, -0.8)
	_seed_rain(8, 0.14)
	_finish_hifi(0.55, 4.2, 4500.0)


## Combat, take D: 132 BPM in 5/4 (3 + 3 + 4 eighths), 28 bars (64 s). A muffled slit drum
## pulses under everything; a bowed D2 drones, its fifth sagging. Bars 0-11 keep it lean:
## a knock that the woods answer, the low marimba knocking the motif's first notes, a scrape
## of bark at the end of every other bar. Bars 12-23 tighten without getting louder: a
## bowed Eb2 grinds a semitone above the drone, bowed bass notes push on the off-groups,
## ticks run in sixteenths, a rattle swells into every fourth bar and the scrapes come
## every bar. Bars 24-27 thin out again into the top of the loop.
func _make_d_combat() -> void:
	_begin(132.0, 28, true, 0.0, 20)
	_r3_master(0.85)
	_wind(0.006, 4, 120.0, 1200.0)
	_pans = {"thump": 0.0, "slit": -0.25, "lowmarimba": -0.4, "scrape": 0.5, "tick": 0.35, "rattle": -0.6}
	for bar in 28:
		var b := bar * 20
		_hit("thump", 38, b, 0.75, 0.25)
		_hit("thump", 38, b + 6, 0.45, 0.25)
		_hit("thump", 38, b + 12, 0.55, 0.25)
		if bar % 2 == 1:
			_hit("slit", 33, b + 16, 0.28, 0.35)
		var mid := bar >= 12 and bar < 24
		if mid or bar % 2 == 1:
			_hit("scrape", 79, b + 16, 0.22 if mid else 0.16, 0.4, 4.0)
		if mid:
			_pattern_at("tick", b, "x.o.x.o.o.x.o.x.o.o.", 77, 0.12, 0.2)
			_hit("bowed", 40 if bar % 2 == 0 else 39, b + 6, 0.22, 0.4, 5.0, -1, 0.0, 0.45)
			_hit("bowed", 39, b + 12, 0.2, 0.4, 6.0, -1, 0.0, -0.45)
			if bar % 4 == 3:
				_hit("rattle", 88, b + 2, 0.16, 0.4, 18.0)
	# The drone, bowed in four-bar strokes, and a fifth that sags.
	for k in 7:
		_hit("bowedpair", 38, k * 80, 0.42, 0.45, 84.0, -1, 0.0, -0.2 if k % 2 == 0 else 0.2)
	for k in [0, 2, 5]:
		_hit("bowed", 45, k * 80 + 20, 0.2, 0.5, 50.0, 44, 0.0, 0.3)
	# Eb2 against the D2 in the middle section.
	_hit("bowedpair", 39, 240, 0.22, 0.5, 120.0, -1, 0.0, 0.25)
	_hit("bowedpair", 39, 355, 0.2, 0.5, 120.0, 38.5, 0.0, -0.25)
	# Knock knock, and the woods; the low marimba knocks the motif.
	_knock_at([72, 74], 46, 0.5, -0.55, false)
	_knock_at([82, 84, 89], 44, 0.3, 0.75, true)
	for bar in [2, 6, 10, 14, 18, 22]:
		_line_at("lowmarimba", bar * 20 + 12, "D2:2 D2:3 A2:3", 0.45, 0.35)
	_line_at("lowmarimba", 16 * 20, "D3:2 D3:2 r:2 A2:4 G2:2 F2:2 G2:2 r:4", 0.35, 0.35)
	_line_at("lowmarimba", 20 * 20, "F2:2 D2:2 C2:2 Ab1/A1:4 r:6 D2:4!", 0.4, 0.35)
	_finish_hifi(0.4, 2.6, 5000.0)


## Out of the village, take E: 84 BPM in 5/4, 21 bars (75 s). A hollow log drones on D2 in
## long breaths, its mouth moving. Three woodpeckers tick at their own pace, every 6, 10
## and 14 sixteenths (3 against 5 against 7, meeting again only at the loop), each fading in
## and out, and now and then one drums a roll far off. A wooden tongue drum walks round a
## 7-step cycle. The balafon picks at the motif low and wrong: its leap turned into a
## tritone down, a minor ninth, the tumble an octave below. Knocks, and the woods answer
## with five; the second time a woodpecker answers instead. Seed rattles, seeds drop.
func _make_e_outside() -> void:
	_begin(84.0, 21, true, 0.0, 20)
	_r3_master(0.8)
	_wind(0.008, 3, 150.0, 1600.0)
	for k in 4:
		_hit("hollowlog", 38, k * 105, 0.42, 0.35, 100.0, -1, 0.0, 0.05)
	var peckers := [[6, 79, -0.7, 0.0], [10, 74, 0.75, 1.0], [14, 70, 0.1, 2.0]]
	for p in peckers:
		for at in range(0, 420, p[0]):
			var fade := pow(0.5 + 0.5 * sin(TAU * (at / 420.0 * 2.0 + p[3] / 3.0)), 2.0)
			if fade > 0.08:
				_hit("tick", p[1], at, 0.22 * fade, 0.45, 2.0, -1, 0.0, p[2])
	for roll in [[37, 82, -0.8], [151, 80, 0.8], [290, 83, 0.6], [377, 81, -0.6]]:
		_woodpecker(roll[0], roll[1], roll[2], 0.16)
	var walk := [38, 33, 38, 36]
	for k in 60:
		_hit("tongue", walk[k % 4], k * 7, 0.22 if k % 4 == 0 else 0.15, 0.35, 2.0, -1, 0.0, -0.15)
	_pans = {"balafon": -0.3, "knock": 0.5, "knockfar": -0.75, "rattle": 0.6}
	_line_at("balafon", 40, "D3:2 D3:2 r:2 Ab2:6", 0.5, 0.45)
	_line_at("balafon", 120, "G2:2 F2:2 G2:4 r:4 Eb3:6", 0.45, 0.45)
	_line_at("balafon", 230, "D3:2 D3:2 r:2 A3:4 C3:2 A2:4 Ab2/A2:6", 0.45, 0.45)
	_line_at("balafon", 330, "F2:3 D2:3 C2:3 Ab1/A1:6 r:3 D2:6!", 0.5, 0.45)
	_knock_at([90, 92], 46, 0.5, 0.5, false)
	_knock_at([100, 101.5, 103, 104.5, 106], 44, 0.25, -0.75, true)
	_knock_at([300, 302], 46, 0.5, 0.5, false)
	_woodpecker(309, 84, -0.85, 0.2)
	_hit("rattle", 92, 170, 0.12, 0.45, 20.0)
	_hit("rattle", 90, 360, 0.1, 0.45, 14.0, -1, 0.0, -0.5)
	_seed_rain(6, 0.12)
	_finish_hifi(0.35, 2.4, 5000.0)


## Combat, take E: 150 BPM in 7/8 (2 + 2 + 3), 48 bars (67 s). The hollow log drones, a
## slit drum and the tongue drum limp along the 7, dry ticks run in sixteenths. Bars 0-15:
## that, a knock and the woods answering, a scrape every fourth bar. Bars 16-39: the balafon
## loops the motif's opening low with a tritone in it, a second tick runs against the first,
## the seed rattle shakes on every long group. Bars 40-47: drums, ticks and drone only.
func _make_e_combat() -> void:
	_begin(150.0, 48, true, 0.0, 14)
	_r3_master(0.85)
	_pans = {"slit": -0.2, "tongue": 0.2, "tick": 0.4, "balafon": -0.35, "rattle": 0.6, "scrape": -0.5}
	for k in 12:
		_hit("hollowlog", 38 if k % 3 != 2 else 36, k * 56, 0.4, 0.3, 54.0, -1, 0.0, 0.0)
	for bar in 48:
		var b := bar * 14
		var mid := bar >= 16 and bar < 40
		_hit("slit", 38, b, 0.7, 0.25)
		_hit("tongue", 33, b + 4, 0.4, 0.25)
		_hit("slit", 38, b + 8, 0.5, 0.25)
		_hit("tongue", 36, b + 11, 0.3 if bar % 2 == 0 else 0.4, 0.25)
		_pattern_at("tick", b, "x.o.x.o.x.o.o.", 77, 0.14, 0.2)
		if mid:
			_pattern_at("tick", b, "..x...x...x..x", 72, 0.1, 0.2)
			_hit("rattle", 88, b + 8, 0.12, 0.3, 4.0)
		if bar % 4 == 3:
			_hit("scrape", 76, b + 9, 0.2, 0.35, 5.0)
	for bar in range(16, 40, 2):
		_line_at("balafon", bar * 14, "D2:2 D2:2 Ab2:2 r:2 G2:2 F2:2 r:2", 0.42, 0.3)
		_line_at("balafon", bar * 14 + 14, "D2:2 D2:2 r:2 r:2 C3:2 A2:2 r:2", 0.36 if bar < 32 else 0.42, 0.3)
	_knock_at([42, 44], 46, 0.5, -0.5, false)
	_knock_at([52, 53.5, 55, 56.5, 58], 44, 0.25, 0.75, true)
	_finish_hifi(0.25, 1.8, 5500.0)


## Out of the village, take F: 60 BPM, 18 bars of 4/4 (72 s), though nothing keeps to them.
## Hardly any notes: wind blowing across a hollow trunk sounds its odd resonances, a beam
## groans, seeds drop, and somewhere far off a heartbeat thumps in the rhythm of the knock,
## on a cycle of its own. A bass flute breathes a few low tones, mostly air: D3, Ab2
## creeping up to A2, D3 sagging a quarter tone, and the two knocks. The low marimba plays
## three notes in the whole loop. Somebody knocks; the heartbeat answers.
func _make_f_outside() -> void:
	_begin(60.0, 18, true)
	_r3_master(0.6)
	_wind(0.03, 2, 50.0, 1400.0, [92.0, 196.0, 311.0])
	_wind(0.006, 3, 300.0, 2500.0)
	_pans = {"breathflute": -0.25, "lowmarimba": 0.35, "thump": 0.55}
	for at in [0, 44, 77, 121, 154, 198, 231, 275]:
		_hit("thump", 38, at, 0.38, 0.55)
		_hit("thump", 38, at + 1.5, 0.26, 0.55)
	_hit("breathflute", 50, 10, 0.4, 0.65, 12.0)
	_hit("breathflute", 44, 58, 0.38, 0.65, 16.0, 45)
	_hit("breathflute", 53, 120, 0.3, 0.65, 10.0)
	_hit("breathflute", 50, 170, 0.4, 0.65, 20.0, 49.5)
	_hit("breathflute", 50, 230, 0.35, 0.65, 3.0)
	_hit("breathflute", 50, 234, 0.32, 0.65, 3.0)
	_hit("lowmarimba", 38, 96, 0.4, 0.55)
	_hit("lowmarimba", 44, 100, 0.32, 0.55)
	_hit("lowmarimba", 48, 252, 0.3, 0.55)
	_hit("bowed", 33, 140, 0.3, 0.5, 60.0, -1, 0.0, -0.1)
	_hit("groan", 34, 30, 0.3, 0.6, 24.0, -1, 0.0, -0.6)
	_hit("groan", 31, 135, 0.28, 0.6, 30.0, -1, 0.0, 0.4)
	_hit("groan", 37, 205, 0.22, 0.6, 20.0, -1, 0.0, -0.2)
	_knock_at([180, 182], 46, 0.45, -0.6, false)
	_hit("thump", 38, 187, 0.3, 0.6, 2.0, -1, 0.0, 0.8)
	_hit("thump", 38, 188.5, 0.22, 0.6, 2.0, -1, 0.0, 0.8)
	_seed_rain(12, 0.13)
	_finish_hifi(0.6, 5.0, 3500.0)


## Combat, take F: 96 BPM in 12/8, 28 bars (70 s). The heartbeat drives it, lub-dub on
## beats one and three (the knock again), against seed shakes and ticks in fours, three to
## the bar. A bowed D2 throbs on the downbeat with a short Eb2 on the last beat. Bars 0-11:
## that, wind through the trunk, a beam groaning every fourth bar. Bars 12-23: the heart
## gets ghost beats, the bowed bass glides between A1 and Ab1, the bass flute breathes the
## knock and the tritone in short bursts and bark is scraped at the end of every other bar.
## Bars 24-27: heart, shakes and wind, into the top.
func _make_f_combat() -> void:
	_begin(96.0, 28, true, 0.0, 12, 3)
	_r3_master(0.85)
	_wind(0.02, 4, 50.0, 1400.0, [92.0, 196.0, 311.0])
	_pans = {"thump": 0.0, "rattle": 0.5, "tick": -0.45, "breathflute": -0.25, "scrape": 0.55, "groan": -0.5}
	for bar in 28:
		var b := bar * 12
		var mid := bar >= 12 and bar < 24
		for beat in [0, 6]:
			_hit("thump", 38, b + beat, 0.75 if beat == 0 else 0.6, 0.3)
			_hit("thump", 38, b + beat + 1, 0.45, 0.3)
		if mid:
			_hit("thump", 38, b + 3, 0.22, 0.3)
			_hit("thump", 38, b + 10, 0.25, 0.3)
		for q in [0, 4, 8]:
			_hit("rattle", 90, b + q, 0.12 if q == 0 else 0.09, 0.25, 1.5)
			_hit("tick", 75, b + q + 2, 0.1, 0.3)
		if bar < 24:
			_hit("bowed", 38, b, 0.3, 0.35, 5.0, -1, 0.0, -0.2)
			_hit("bowed", 39, b + 9, 0.18, 0.35, 2.5, -1, 0.0, 0.2)
		if bar % 4 == 2:
			_hit("groan", 33, b + 4, 0.2, 0.5, 8.0)
		if mid and bar % 2 == 1:
			_hit("scrape", 78, b + 9, 0.2, 0.35, 3.0)
	for k in 3:
		_hit("bowedpair", 33, (12 + k * 4) * 12, 0.22, 0.4, 46.0, 32, 0.0, 0.3)
	for bar in [13, 17, 21]:
		_line_at("breathflute", bar * 12 + 2, "D3:1 D3:1 r:1 Ab2:2", 0.4, 0.45)
	for bar in [3, 15, 23]:
		_line_at("lowmarimba", bar * 12 + 10, "D2:1 D2:1", 0.4, 0.35)
	_finish_hifi(0.4, 2.8, 4000.0)


## The round-3 master: the peaks barely squeezed and normalised to `level`. The levels are
## set so the outside cues measure about -19 to -21 LUFS and the fights about -16 to -18.
func _r3_master(level: float) -> void:
	_drive = 0.3
	_level = level


## Like _line, but from step `at` and without bar lines.
func _line_at(inst: String, at: float, text: String, vel: float, verb: float, echo := 0.0) -> void:
	for token in text.split(" ", false):
		var accent := token.ends_with("!")
		var parts := token.trim_suffix("!").split(":")
		var steps := float(parts[1])
		if parts[0] != "r":
			var pitches := parts[0].split("/")
			var glide := float(_midi(pitches[1])) if pitches.size() > 1 else -1.0
			_hit(inst, _midi(pitches[0]), at, vel * (1.25 if accent else 1.0), verb, steps, glide, echo)
		at += steps


## Like _pattern, for one bar from step `at`.
func _pattern_at(inst: String, at: int, pattern: String, midi: int, vel: float, verb: float) -> void:
	for s in pattern.length():
		var c := pattern[s]
		if c != ".":
			_hit(inst, midi, at + s, vel * (1.3 if c == "X" else 0.45 if c == "o" else 1.0), verb, 1.0)


## Knocks on wood at each of `steps`, tuned to `midi`, at `pan`; `far` puts them out in the
## trees, with more room around them.
func _knock_at(steps: Array, midi: int, vel: float, pan: float, far: bool) -> void:
	for s in steps:
		_hit("knockfar" if far else "knock", midi, s, vel, 0.75 if far else 0.3, 2.0, -1, 0.0, pan)


## A woodpecker drumming a roll at step `at`: a dozen fast ticks that speed up and fade.
func _woodpecker(at: float, midi: int, pan: float, vel: float) -> void:
	var t := at
	for k in 12:
		_hit("tick", midi, t, vel * (1.0 - k * 0.06), 0.7, 2.0, -1, 0.0, pan)
		t += (0.055 - k * 0.002) / _step


## `count` seeds dropping at random through the loop, anywhere around the listener.
func _seed_rain(count: int, vel: float) -> void:
	var total := _dry.size() / float(_rate) / _step
	for k in count:
		_hit("seedfall", 72 + k, rng.randf_range(0.0, total), vel * rng.randf_range(0.5, 1.0), 0.7, 2.0, -1, 0.0, rng.randf_range(-0.9, 0.9))


# --- Sequencing ---------------------------------------------------------------------------


## Starts a cue `bars` long at `bpm`. A bar is `meter` steps, `per_beat` of them to a beat:
## sixteen sixteenths by default, so 4/4; 20 and 4 make 5/4, 14 and 4 make 7/8 and 12 and
## 3 make 12/8. A looping cue wraps everything that rings past its end; a one-shot gets
## `tail` seconds to ring out instead.
func _begin(bpm: float, bars: int, loop: bool, tail := 0.0, meter := 16, per_beat := 4) -> void:
	_step = 60.0 / bpm / per_beat
	_meter = meter
	_loop = loop
	_damp = 0.35
	_master_lp = 0.0
	_drive = 1.3
	_level = 0.84
	_pans = {}
	_pan_spread = 0.0
	var n := _seconds(bars * meter * _step + tail)
	_dry = _silence_samples(n)
	_verb = _silence_samples(n)
	_echo = _silence_samples(n)
	if _stereo:
		_dry_r = _silence_samples(n)
		_verb_r = _silence_samples(n)
		_echo_r = _silence_samples(n)


## A softer master for the round-2 cues: a darker reverb (`damp`), a low-pass over the whole
## mix at `lowpass` Hz, the peaks barely squeezed and a little more headroom.
func _warm(damp: float, lowpass: float) -> void:
	_damp = damp
	_master_lp = lowpass
	_drive = 0.7
	_level = 0.78


## Plays a text score (see the header) on `inst` from bar `bar`. `transpose` shifts it in
## semitones, `stretch` scales its durations, and `pitch_map` moves pitch classes, e.g.
## {9: -1} flattens every A; `echo` sends it to the echo too.
func _line(inst: String, bar: int, text: String, vel: float, verb: float, transpose := 0, stretch := 1.0, pitch_map := {}, echo := 0.0) -> void:
	var at := float(bar * _meter)
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
				_hit(inst, midi, at, vel * (1.25 if accent else 1.0), verb, steps * stretch, glide, echo)
			at += steps * stretch
		if not is_equal_approx(length, _meter):
			push_warning("%s: a bar of %s steps in '%s'" % [inst, length, measure])


## Plays a one-bar step pattern (repeated if shorter than `bars`) on `inst` at `midi`.
func _pattern(inst: String, bar: int, bars: int, pattern: String, midi: int, vel: float, verb: float, echo := 0.0) -> void:
	for s in bars * _meter:
		var c := pattern[s % pattern.length()]
		if c != ".":
			var v := vel * (1.3 if c == "X" else 0.45 if c == "o" else 1.0)
			_hit(inst, midi, bar * _meter + s, v, verb, 1.0, -1, echo)


## One note: `inst` at `midi` (sliding to `glide` if it is not -1) at step `at`, `steps`
## long. Struck instruments get a few milliseconds of slop and a little velocity jitter,
## so the groove doesn't sound like a sequencer. In stereo the note stands at `pan`, or
## where `_pans` puts its instrument, give or take `_pan_spread`.
func _hit(inst: String, midi: float, at: float, vel: float, verb: float, steps := 2.0, glide := -1.0, echo := 0.0, pan := INF) -> void:
	if inst in _muted:
		return
	var sustained := inst in SUSTAINED
	var length := steps * _step
	var t := at * _step
	if inst in MELODIC:
		_range = Vector2(minf(_range.x, minf(midi, glide if glide >= 0 else midi)), maxf(_range.y, maxf(midi, glide)))
	if _stereo:
		vel *= float(R3_MIX.get(inst, 1.0))
		if pan == INF:
			pan = float(_pans.get(inst, 0.0))
		if _pan_spread > 0.0:
			pan += rng.randf_range(-_pan_spread, _pan_spread)
	if not sustained:
		t += rng.randf_range(-0.004, 0.004)
		vel *= rng.randf_range(0.9, 1.05)
		if glide >= 0:
			# A struck bar can't slide: play the first pitch as a grace note.
			_mix_bus(_note(inst, midi, length, -1), t - _step * 0.5, vel * 0.7, verb, echo, pan)
			midi = glide
	_mix_bus(_note(inst, midi, length, glide if sustained else -1.0), t, vel, verb, echo, pan)


## Mixes a note into the buses at `t` seconds. In stereo it is panned with constant power;
## its reverb send sits halfway to the middle, so the room is around it, not only on its side.
func _mix_bus(x: PackedFloat32Array, t: float, vel: float, verb: float, echo: float, pan := 0.0) -> void:
	var offset := _seconds(maxf(t, 0.0))
	if not _stereo:
		_mix_wrap(_dry, x, offset, vel)
		if verb > 0.0:
			_mix_wrap(_verb, x, offset, vel * verb)
		if echo > 0.0:
			_mix_wrap(_echo, x, offset, vel * echo)
		return
	var side := (clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25
	_mix_wrap(_dry, x, offset, vel * cos(side) * sqrt(2.0))
	_mix_wrap(_dry_r, x, offset, vel * sin(side) * sqrt(2.0))
	if verb > 0.0:
		var room := (clampf(pan, -1.0, 1.0) * 0.5 + 1.0) * PI * 0.25
		_mix_wrap(_verb, x, offset, vel * verb * cos(room) * sqrt(2.0))
		_mix_wrap(_verb_r, x, offset, vel * verb * sin(room) * sqrt(2.0))
	if echo > 0.0:
		_mix_wrap(_echo, x, offset, vel * echo * cos(side) * sqrt(2.0))
		_mix_wrap(_echo_r, x, offset, vel * echo * sin(side) * sqrt(2.0))


## A rendered note, cached by everything that shapes it.
func _note(inst: String, midi: float, length: float, glide: float) -> PackedFloat32Array:
	var key := "%s %s %.3f %s" % [inst, midi, length if inst in SUSTAINED else 0.0, glide]
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
		# Round 2: the soft wood.
		"softmarimba":
			return _soft_marimba(f)
		"kalimba":
			return _kalimba(f)
		"balafon":
			return _balafon(f)
		"tongue":
			return _tongue_drum(f)
		"feltblock":
			return _soften(_block(f, [1.0, 2.71, 4.4], [0.06, 0.02, 0.01], 0.0), 0.002, 1800.0, [230.0, 520.0])
		"felttemple":
			return _soften(_block(f * 0.5, [1.0, 2.2, 3.6], [0.14, 0.04, 0.015], 0.03), 0.002, 1600.0, [180.0, 410.0])
		"softlog":
			return _soften(_logdrum(f), 0.004, 650.0, [])
		"shaker":
			return _lowpass(_shape(_bandpass(_noise(0.07), 2600.0, 0.8), 0.007, 0.022), 4200.0, 0.7)
		"bamboo":
			return _bamboo_chime(f)
		"woodfrog":
			return _wood_frog()
		"flute":
			return _soft_flute(f, length, glide)
		"softcreak":
			return _lowpass(_creak(), 1400.0, 0.7)
		"softmukkuri":
			return _lowpass(_mukkuri(f), 1100.0, 0.7)
		# Round 3: low, bowed, breathed and scraped wood.
		"bowed":
			return _bowed(f, length, glide, 0.0, minf(1.2, length * 0.3))
		"bowedpair":
			return _bowed(f, length, glide, 7.0, minf(2.5, length * 0.4))
		"breathflute":
			return _breath_flute(f, length, glide)
		"hollowlog":
			return _hollow_log(f, length)
		"lowmarimba":
			return _low_marimba(f)
		"slit":
			return _slit(f, 2200.0)
		"thump":
			return _slit(f, 800.0)
		"knock":
			return _wood_knock(f, false)
		"knockfar":
			return _wood_knock(f, true)
		"tick":
			return _tick(f)
		"scrape":
			return _scrape(length, f)
		"rattle":
			return _rattle(length, f)
		"groan":
			return _groan(f, length)
		"seedfall":
			return _seed_fall()
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
		var t := float(i) / _rate
		phase += TAU * f * (1.0 + 0.4 * exp(-t / 0.025)) / _rate
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
	var period := float(_rate) / f
	var size := int(period) + 2
	var line := _noise(float(size) / _rate)
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
		var t := float(i) / _rate
		var target := f
		if glide > 0.0 and t > length * 0.45:
			target = f * pow(glide / f, clampf((t - length * 0.45) / (length * 0.4), 0.0, 1.0))
		var scoop := pow(2.0, -exp(-t / 0.018) / 12.0)
		var vibrato := 1.0 + 0.007 * sin(TAU * 5.6 * t) * clampf((t - 0.22) / 0.3, 0.0, 1.0)
		phase += TAU * target * scoop * vibrato / _rate
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
		var t := float(i) / _rate
		var k := pow(t / length, 1.6)
		phase += TAU * from * pow(to / from, k) * (1.0 + 0.012 * sin(TAU * 6.5 * t)) / _rate
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
		phase = fposmod(phase + f / _rate, 1.0)
		reed[i] = 1.0 if phase < 0.12 else -0.14
	var freqs := PackedFloat32Array()
	freqs.resize(n)
	for i in n:
		var t := float(i) / _rate
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
		var t := float(i) / _rate
		var rate := 38.0 + 30.0 * sin(TAU * 0.9 * t + 1.0) + 14.0 * sin(TAU * 3.1 * t)
		phase += rate / _rate
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


# --- Round 2: soft wood -------------------------------------------------------------------


## A marimba played with rubber yarn mallets: a slower, rounder attack, hardly any of the
## bar's bright overtone, a long ringing fundamental from the resonator tube and the soft
## thud of the mallet head.
func _soft_marimba(f: float) -> PackedFloat32Array:
	var d := clampf(0.95 * sqrt(220.0 / f), 0.3, 1.8)
	var out := _partials(d * 3.0, f, [1.0, 3.93, 2.0], [1.0, 0.05, 0.04], [d, d * 0.15, d * 0.3], 0.0)
	_mix(out, _shape(_lowpass(_noise(0.03), 380.0, 0.7), 0.002, 0.012), 0, 0.15)
	out = _wood_body(out, [190.0, 430.0], 4.0, 0.35)
	return _lowpass(_shape(out, 0.004, 100.0), clampf(f * 4.0, 900.0, 2800.0), 0.7)


## A kalimba: steel tongues on a hollow wooden box, plucked with a thumb. A long pure
## fundamental, the tine's high inharmonic ping that dies at once, and the box booming
## under the pluck.
func _kalimba(f: float) -> PackedFloat32Array:
	var d := clampf(1.0 * sqrt(440.0 / f), 0.45, 1.5)
	var out := _partials(d * 3.0, f, [1.0, 5.9, 2.0], [1.0, 0.08, 0.05], [d, 0.04, d * 0.25], 0.0)
	_mix(out, _shape(_lowpass(_noise(0.03), 900.0, 0.7), 0.001, 0.006), 0, 0.25)
	out = _wood_body(out, [240.0, 560.0, 1150.0], 4.0, 0.5)
	return _lowpass(_shape(out, 0.0025, 100.0), 3000.0, 0.7)


## A balafon: a dry hardwood bar over a gourd, struck with a padded beater. The bar dies
## faster than a marimba's, the gourd colours it, and the spider-silk membrane over the
## gourd's hole buzzes very softly along with the fundamental.
func _balafon(f: float) -> PackedFloat32Array:
	var d := clampf(0.45 * sqrt(220.0 / f), 0.12, 0.8)
	var out := _partials(d * 3.0, f, [1.0, 3.9, 8.8], [1.0, 0.18, 0.04], [d, d * 0.2, d * 0.06], 0.004)
	var buzz := _partials(d * 2.0, f, [1.0], [1.0], [d * 0.7], 0.0)
	for i in buzz.size():
		buzz[i] = tanh(buzz[i] * 3.0) / tanh(3.0) - buzz[i]
	_mix(out, _bandpass(buzz, 1100.0, 1.0), 0, 0.5)
	_mix(out, _shape(_lowpass(_noise(0.02), minf(f * 1.5, 1800.0), 0.8), 0.001, 0.006), 0, 0.3)
	out = _wood_body(out, [210.0, 470.0], 4.0, 0.45)
	return _lowpass(_shape(out, 0.0018, 100.0), 3400.0, 0.7)


## A wooden tongue drum: a box with tongues cut into its lid, hit with a soft rubber
## beater. A hollow, slightly bending "tung" with a lot of box in it.
func _tongue_drum(f: float) -> PackedFloat32Array:
	var d := clampf(0.4 * sqrt(220.0 / f), 0.18, 0.9)
	var out := _partials(d * 4.0, f, [1.0, 2.32, 3.86], [1.0, 0.28, 0.07], [d, d * 0.25, d * 0.1], 0.015)
	_mix(out, _shape(_lowpass(_noise(0.04), 320.0, 0.7), 0.002, 0.014), 0, 0.4)
	out = _wood_body(out, [140.0, 310.0, 690.0], 5.0, 0.5)
	return _lowpass(_shape(out, 0.003, 100.0), 2200.0, 0.7)


## A hollow bamboo tube from a wind chime knocking against its neighbour: "tok".
func _bamboo_chime(f: float) -> PackedFloat32Array:
	var out := _partials(0.8, f, [1.0, 2.76, 5.4], [1.0, 0.35, 0.1], [0.2, 0.07, 0.03], 0.0)
	_mix(out, _shape(_bandpass(_noise(0.01), f * 2.0, 2.0), 0.0005, 0.003), 0, 0.2)
	return _lowpass(_shape(out, 0.001, 100.0), 3200.0, 0.7)


## A carved wooden frog with a ridged back: a stick drawn along the ridges, a stuttering
## little croak through its hollow belly, and a tap on the nose at the end.
func _wood_frog() -> PackedFloat32Array:
	var length := 0.6
	var n := _seconds(length)
	var pulses := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / _rate
		if t > 0.38:
			break
		phase += (22.0 + 20.0 * t / 0.38) / _rate
		if phase >= 1.0:
			phase -= 1.0
			pulses[i] = rng.randf_range(0.7, 1.0)
	pulses[_seconds(0.46)] = 1.6
	var out := _bandpass(pulses, 820.0, 9.0)
	_mix(out, _bandpass(pulses, 1750.0, 10.0), 0, 0.45)
	_mix(out, _bandpass(pulses, 360.0, 7.0), 0, 0.8)
	return _lowpass(out, 2600.0, 0.7)


## A breathy low bamboo flute, nearer a shakuhachi than the shinobue: a slow, airy
## attack, a quarter-tone scoop, a pure tone and a long soft breath; with `glide` it
## slides there over the note's second half.
func _soft_flute(f: float, length: float, glide: float) -> PackedFloat32Array:
	var n := _seconds(length + 0.18)
	var breath := _bandpass(_noise(length + 0.18), f, 3.0)
	var air := _lowpass(_highpass(_noise(length + 0.18), 900.0, 0.7), 3500.0, 0.7)
	var out := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / _rate
		var target := f
		if glide > 0.0 and t > length * 0.45:
			target = f * pow(glide / f, clampf((t - length * 0.45) / (length * 0.45), 0.0, 1.0))
		var scoop := pow(2.0, -exp(-t / 0.05) / 24.0)
		var vibrato := 1.0 + 0.005 * sin(TAU * 4.8 * t) * clampf((t - 0.35) / 0.4, 0.0, 1.0)
		phase += TAU * target * scoop * vibrato / _rate
		var env := minf(1.0, t / 0.07) * clampf((length + 0.15 - t) / 0.15, 0.0, 1.0)
		var tone := sin(phase) + 0.1 * sin(2.0 * phase) + 0.025 * sin(3.0 * phase)
		var puff := exp(-t / 0.06)
		out[i] = env * (tone * 0.7 + breath[i] * 1.2 + air[i] * (0.06 + 0.12 * puff))
	return _lowpass(out, 2400.0, 0.7)


## Muffles a harder instrument: a slower attack of `attack` seconds, a low-pass at
## `lowpass` Hz and, if `body` lists any, the resonances of a wooden body.
func _soften(x: PackedFloat32Array, attack: float, lowpass: float, body: Array) -> PackedFloat32Array:
	var out := _shape(x, attack, 100.0)
	if not body.is_empty():
		out = _wood_body(out, body, 4.0, 0.4)
	return _lowpass(out, lowpass, 0.7)


## The resonances of a wooden body (a box, a gourd, a hollow log): band-passed copies of
## the sound at each of `modes` Hz, added back in. They ring a little after the strike,
## which is most of what makes a thing sound hollow and wooden.
func _wood_body(x: PackedFloat32Array, modes: Array, q: float, gain: float) -> PackedFloat32Array:
	var out := x.duplicate()
	for m in modes:
		_mix(out, _bandpass(x, m, q), 0, gain)
	return out


# --- Round 3: low, bowed, breathed and scraped wood ---------------------------------------
# Rendered at 44.1 kHz and with more care than the lo-fi rounds: slow random drift in pitch
# and pressure (see _wander), noise layers shaped by the tone, paired voices a few cents
# apart and the resonances of a wooden body under almost everything.


## A wooden bar or plank bowed with a rosined bow, the way players bow marimba bars: the
## bar locks into its fundamental, so the tone is round, with a few soft harmonics, the
## bar's own inharmonic mode and the rasp of the bow riding on top. Bow pressure
## wanders, so the note breathes, and the bar rings on a little once the bow lifts.
## `detune` (cents) adds a second bow on a twin bar that far off, which beats slowly against
## the first; `swell` is the attack in seconds; with `glide` the note bends there over its
## second half.
func _bowed(f: float, length: float, glide: float, detune: float, swell: float) -> PackedFloat32Array:
	var total := length + 1.2
	var n := _seconds(total)
	var pressure := _wander(total, 1.2)
	var flutter := _wander(total, 25.0)
	var rasp := _rms_norm(_bandpass(_noise(total), clampf(f * 3.0, 250.0, 2400.0), 1.4))
	var twin := pow(2.0, detune / 1200.0)
	var out := _silence_samples(n)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	for i in n:
		var t := float(i) / _rate
		var target := f
		if glide > 0.0:
			target = f * pow(glide / f, smoothstep(length * 0.5, length * 0.9, t))
		p1 += TAU * target / _rate
		p2 += TAU * target * twin / _rate
		var attack := smoothstep(0.0, swell, t)
		var ring := 1.0 if t < length else exp(-(t - length) / 0.4)
		var bow := 1.0 if t < length else exp(-(t - length) / 0.04)
		var push := 0.8 + 0.2 * pressure[i]
		var tone := sin(p1) + 0.3 * sin(2.0 * p1) + 0.14 * sin(3.0 * p1) + 0.06 * sin(4.0 * p1) + 0.04 * sin(3.93 * p1)
		if detune != 0.0:
			tone = (tone + 0.45 * (sin(p2) + 0.3 * sin(2.0 * p2) + 0.14 * sin(3.0 * p2))) * 0.7
		out[i] = attack * push * (ring * tone * (1.0 + 0.04 * flutter[i]) + bow * rasp[i] * 0.07)
	out = _wood_body(out, [165.0, 380.0, 840.0], 3.0, 0.25)
	return _lowpass(out, 2600.0, 0.7)


## A low bamboo flute played breathy, close to a bass shakuhachi: the air comes first and
## the tone grows out of it with a quarter-tone scoop. The breath noise puffs with every
## cycle of the tone, as it does in a real flute, the pitch drifts by a few cents, a slow
## vibrato comes in late, and there is air on top of it all. With `glide` it slides there
## over the second half of the note.
func _breath_flute(f: float, length: float, glide: float) -> PackedFloat32Array:
	var total := length + 0.35
	var n := _seconds(total)
	var air := _rms_norm(_bandpass(_noise(total), clampf(f * 2.0, 150.0, 1800.0), 1.2))
	var hiss := _rms_norm(_lowpass(_highpass(_noise(total), 700.0, 0.7), 4000.0, 0.7))
	var drift := _wander(total, 0.8)
	var out := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / _rate
		var target := f
		if glide > 0.0:
			target = f * pow(glide / f, smoothstep(length * 0.45, length * 0.9, t))
		var scoop := pow(2.0, -exp(-t / 0.09) / 24.0)
		var vibrato := 1.0 + 0.004 * sin(TAU * 4.6 * t) * smoothstep(0.5, 1.2, t) + 0.0025 * drift[i]
		phase += TAU * target * scoop * vibrato / _rate
		var release := clampf((length + 0.3 - t) / 0.3, 0.0, 1.0)
		var tone := sin(phase) + 0.22 * sin(2.0 * phase) + 0.07 * sin(3.0 * phase) + 0.02 * sin(4.0 * phase)
		var puff := 0.55 + 0.45 * sin(phase)
		out[i] = release * (smoothstep(0.03, 0.25, t) * tone * 0.6 + smoothstep(0.0, 0.05, t) * (air[i] * puff * 0.14 + hiss[i] * 0.03))
	return _lowpass(out, 3200.0, 0.7)


## A hollow log blown like a didgeridoo (they are eucalyptus trunks hollowed by termites):
## buzzing lips at `f` drive the long wooden tube, and the player's mouth moves its two
## formants slowly, which is most of what you hear. The buzz wavers with the lips.
func _hollow_log(f: float, length: float) -> PackedFloat32Array:
	var total := length + 0.3
	var n := _seconds(total)
	var mouth := _wander(total, 0.35)
	var lips := _wander(total, 6.0)
	var buzz := _silence_samples(n)
	var f1 := PackedFloat32Array()
	var f2 := PackedFloat32Array()
	f1.resize(n)
	f2.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / _rate
		phase += TAU * f * (1.0 + 0.004 * lips[i]) / _rate
		var env := smoothstep(0.0, 0.15, t) * clampf((total - t) / 0.3, 0.0, 1.0)
		buzz[i] = pow(0.5 + 0.5 * sin(phase), 6.0) * env * (0.85 + 0.15 * lips[i])
		f1[i] = 430.0 + 170.0 * mouth[i]
		f2[i] = 1300.0 - 320.0 * mouth[i]
	buzz = _highpass(buzz, 30.0, 0.7)
	var out := _silence_samples(n)
	_mix(out, _lowpass(buzz, f * 2.5, 0.7), 0, 0.6)
	_mix(out, _filter_swept(buzz, "bandpass", f1, 5.0), 0, 4.0)
	_mix(out, _filter_swept(buzz, "bandpass", f2, 7.0), 0, 1.6)
	return _peak_norm(_lowpass(out, 2500.0, 0.7), 0.6)


## A bass marimba with padded mallets, its notes doubled on a second bar tuned six cents
## away, as gamelan pairs are, so long low notes shimmer slowly instead of standing still.
func _low_marimba(f: float) -> PackedFloat32Array:
	var out := _soft_marimba(f)
	_mix(out, _soft_marimba(f * 1.0035), 0, 0.7)
	return out


## A big slit log drum: a tongue cut into a hollowed trunk, hit with a padded beater. A low
## mode with its wooden partials that bends down a little as it settles, the thud of the
## beater, and the trunk's cavity booming under it; `lowpass` is how hard the beater is.
func _slit(f: float, lowpass: float) -> PackedFloat32Array:
	var out := _partials(2.5, f, [1.0, 2.45, 4.1, 6.6], [1.0, 0.5, 0.25, 0.1], [0.6, 0.25, 0.1, 0.05], 0.035)
	_mix(out, _shape(_rms_norm(_lowpass(_noise(0.12), 260.0, 0.7)), 0.002, 0.025), 0, 0.25)
	out = _wood_body(out, [85.0, 190.0, 430.0], 5.0, 0.6)
	return _lowpass(_shape(out, 0.0015, 100.0), lowpass, 0.7)


## A knuckle on a hollow trunk or a door, tuned to `f`; `far` puts it out in the trees:
## duller, softer at the start.
func _wood_knock(f: float, far: bool) -> PackedFloat32Array:
	var out := _partials(0.4, f, [1.0, 1.6, 2.3, 3.9], [1.0, 0.7, 0.5, 0.2], [0.08, 0.055, 0.035, 0.02], 0.02)
	_mix(out, _shape(_rms_norm(_lowpass(_noise(0.05), 700.0, 0.8)), 0.0005, 0.012), 0, 0.12)
	_mix(out, _shape(_rms_norm(_bandpass(_noise(0.01), 2200.0, 1.5)), 0.0002, 0.002), 0, 0.04)
	out = _wood_body(out, [f * 0.8, 260.0], 4.0, 0.3)
	return _lowpass(_shape(out, 0.003, 100.0), 750.0, 0.7) if far else out


## A small dry tick, a twig or a beak on hard wood: a short hollow block, rounded off.
func _tick(f: float) -> PackedFloat32Array:
	return _lowpass(_block(f, [1.0, 2.6, 4.3], [0.025, 0.01, 0.005], 0.0), 3500.0, 0.7)


## A seed or a twig dropping somewhere onto the forest floor: a tick and a smaller bounce.
func _seed_fall() -> PackedFloat32Array:
	var f := rng.randf_range(700.0, 1300.0)
	var out := _tick(f)
	var bounce := _tick(f * rng.randf_range(1.05, 1.2))
	out.resize(out.size() + _seconds(0.15))
	_mix(out, bounce, _seconds(rng.randf_range(0.06, 0.12)), 0.35)
	return out


## A stick drawn slowly along ridged bark, a guiro made of a branch: every ridge it slips
## over is a tiny impulse that rings the wood at `f` and its modes. The rate wanders as the
## hand slows and hurries, and the stroke swells and fades over `length`.
func _scrape(length: float, f: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var hand := _wander(length, 3.0)
	var pulses := _silence_samples(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / _rate
		phase += (24.0 * (0.8 + 0.5 * t / length) + 7.0 * hand[i]) / _rate
		if phase >= 1.0:
			phase -= 1.0
			pulses[i] = rng.randf_range(0.5, 1.0)
	var out := _bandpass(pulses, f, 7.0)
	_mix(out, _bandpass(pulses, f * 2.3, 9.0), 0, 0.5)
	_mix(out, _bandpass(pulses, f * 0.48, 5.0), 0, 0.7)
	_mix(out, _rms_norm(_bandpass(_noise(length), f, 1.0)), 0, 0.01)
	for i in n:
		out[i] *= pow(sin(PI * float(i) / n), 0.8)
	return _peak_norm(_lowpass(out, 3500.0, 0.7), 0.6)


## A dry seed pod, or nutshells on a string, shaken for `length`: seeds strike the shell at
## random, each click ringing its hollow at about `f`. The shake swells and fades.
func _rattle(length: float, f: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var env := _ramp(n, 0.35, 0.45)
	var clicks := _silence_samples(n)
	for i in n:
		if rng.randf() < 220.0 * env[i] / _rate:
			clicks[i] = rng.randf_range(0.3, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	var out := _bandpass(clicks, f, 2.5)
	_mix(out, _bandpass(clicks, f * 1.9, 3.0), 0, 0.5)
	_mix(out, _bandpass(clicks, f * 0.5, 2.0), 0, 0.4)
	return _peak_norm(_lowpass(out, 4500.0, 0.7), 0.6)


## A beam in an old wooden house groaning under a load: stick-slip like the creak, but slow
## and low, a buzzing train of slips at about `f` a second whose rate wanders, ringing the
## beam's resonances.
func _groan(f: float, length: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var load := _wander(length, 0.9)
	var pulses := _silence_samples(n)
	var phase := 0.0
	for i in n:
		phase += f * (1.0 + 0.22 * load[i]) / _rate
		if phase >= 1.0:
			phase -= 1.0
			pulses[i] = rng.randf_range(0.6, 1.0)
	var out := _bandpass(pulses, 190.0, 9.0)
	_mix(out, _bandpass(pulses, 430.0, 10.0), 0, 0.8)
	_mix(out, _bandpass(pulses, 960.0, 9.0), 0, 0.4)
	_mix(out, _bandpass(pulses, 2100.0, 8.0), 0, 0.12)
	var env := _ramp(n, 0.35, 0.4)
	for i in n:
		out[i] *= env[i] * (0.7 + 0.3 * load[i])
	return _peak_norm(_lowpass(out, 2400.0, 0.7), 0.6)


## Slow random drift, `hz` fast, between -1 and 1: noise through two low-passes.
func _wander(length: float, hz: float) -> PackedFloat32Array:
	return _peak_norm(_lowpass(_lowpass(_noise(length + 0.5), hz, 0.6), hz, 0.6).slice(0, _seconds(length)), 1.0)


func _rms_norm(x: PackedFloat32Array) -> PackedFloat32Array:
	var sum := 0.0
	for v in x:
		sum += v * v
	var rms := sqrt(sum / maxf(x.size(), 1.0))
	var out := x.duplicate()
	if rms > 0.0:
		for i in out.size():
			out[i] /= rms
	return out


func _peak_norm(x: PackedFloat32Array, level: float) -> PackedFloat32Array:
	var top := 0.0
	for v in x:
		top = maxf(top, absf(v))
	var out := x.duplicate()
	if top > 0.0:
		for i in out.size():
			out[i] *= level / top
	return out


## Wind under the whole round-3 cue, different in each ear: noise between `low` and `high`
## Hz at `level`, swelling `gusts` times over the loop (a whole number, so it meets itself).
## With `modes` it blows across a hollow trunk instead, and rings its resonances.
func _wind(level: float, gusts: int, low: float, high: float, modes := []) -> void:
	var n := _dry.size()
	for bus in [_dry, _dry_r]:
		# Filtered twice over and the second pass kept, so the noise has no seam either.
		var raw := _noise(float(n) / _rate)
		raw.append_array(raw)
		var air := _highpass(_lowpass(raw, high, 0.5), low, 0.7)
		if not modes.is_empty():
			var hollow := _silence_samples(air.size())
			for m in modes:
				_mix(hollow, _bandpass(air, m, 8.0), 0, 1.0)
			_mix(hollow, air, 0, 0.15)
			air = hollow
		air = _rms_norm(air.slice(n))
		var phase := rng.randf_range(-0.4, 0.4)
		for i in n:
			var t := float(i) / n
			var swell := 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TAU * gusts * t - PI * 0.5 + phase), 2.0)
			bus[i] += air[i] * level * swell


## Wooden wind chimes over `bars` bars from `bar`: in each bar, with chance `chance`, a
## gust knocks a few bamboo tubes together.
func _chimes(bar: int, bars: int, chance: float, vel: float) -> void:
	var pitches := [74, 77, 79, 81, 84, 86]
	for b in range(bar, bar + bars):
		if rng.randf() > chance:
			continue
		var at := b * 16 + rng.randf_range(0.0, 12.0)
		for k in rng.randi_range(3, 6):
			at += rng.randf_range(0.25, 0.9)
			_hit("bamboo", pitches[rng.randi_range(0, pitches.size() - 1)], at, vel * rng.randf_range(0.45, 1.0), 0.5)


## Wind in the leaves under the whole cue: dark noise at `level` that swells and drops
## `gusts` times over it (a whole number, so a loop meets itself).
func _air(level: float, gusts: int) -> void:
	var n := _dry.size()
	var wind := _highpass(_lowpass(_noise(float(n + 2) / _rate), 700.0, 0.5), 120.0, 0.7)
	for i in n:
		var t := float(i) / n
		var swell := 0.45 + 0.55 * pow(0.5 + 0.5 * sin(TAU * gusts * t - PI * 0.5), 2.0)
		if not _loop:
			swell *= minf(1.0, t / 0.15) * minf(1.0, (1.0 - t) / 0.2)
		_dry[i] += wind[i] * level * swell


## A soft marimba roll on `low` and `high` in eighths, over the bar: the drone pad.
func _roll(bar: int, low: int, high: int, vel: float, verb: float) -> void:
	for s in range(0, 16, 2):
		_hit("softmarimba", low if s % 4 == 0 else high, bar * 16 + s, vel * rng.randf_range(0.8, 1.1), verb)


## A kalimba picking the chord in eighths (root, fifth, octave, fifth) over the bass roots.
func _kalimba_picking(bar: int, count: int, roots: Array, vel: float) -> void:
	for b in range(bar, bar + count):
		var root: int = roots[b % roots.size()]
		var notes := [root + 12, root + 19, root + 24, root + 19]
		for s in range(0, 16, 2):
			_hit("kalimba", notes[int(s / 2.0) % 4], b * 16 + s, vel * (1.0 if s % 8 == 0 else 0.7), 0.3)


# --- Synthesis ----------------------------------------------------------------------------


## Modal synthesis: a sum of exponentially decaying sines at `ratios` of `f`, each with
## its own amplitude and decay; `drop` bends the whole thing down by that fraction
## during the first few milliseconds, as a struck body does.
func _partials(length: float, f: float, ratios: Array, amps: Array, decays: Array, drop: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var out := _silence_samples(n)
	for m in ratios.size():
		var freq: float = f * ratios[m]
		if freq >= _rate * 0.45:
			continue
		var amp: float = amps[m]
		var decay: float = decays[m]
		var phase := rng.randf() * TAU
		for i in n:
			var t := float(i) / _rate
			var e := exp(-t / decay)
			if e < 0.0005:
				break
			phase += TAU * freq * (1.0 + drop * exp(-t / 0.03)) / _rate
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
		var g := pow(0.001, float(delay) / (time * _rate))
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
		var t := float(i) / _rate
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
			var w0 := TAU * clampf(freqs[i], 20.0, _rate * 0.45) / _rate
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
	var start := offset % n
	var first := mini(x.size(), n - start)
	for i in first:
		into[start + i] += x[i] * gain
	for i in range(first, x.size()):
		into[(start + i) % n] += x[i] * gain


func _silence(length: float) -> PackedFloat32Array:
	return _silence_samples(_seconds(length))


func _silence_samples(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	return out


func _seconds(length: float) -> int:
	return int(round(length * _rate))


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


## `midi` as a note name, e.g. 50 -> D3, with a + for a quarter tone above.
func _note_name(midi: float) -> String:
	var names := ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
	var k := int(floor(midi))
	return "%s%d%s" % [names[k % 12], int(k / 12.0) - 1, "+" if midi - k >= 0.25 else ""]


# --- Output -------------------------------------------------------------------------------


## Sums the buses through the reverb (`wet` of it) and, if anything was sent there, the
## echo; squeezes the peaks a little, normalises and writes the cue. Round 3 goes through
## _finish_hifi instead.
func _finish(wet: float, room := 1.6) -> void:
	var out := _dry.duplicate()
	var verb := _reverb(_verb, room, _damp)
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
	if _master_lp > 0.0:
		# A loop is filtered twice over and the second pass kept, so the seam stays clean.
		var input := out.duplicate()
		if _loop:
			input.append_array(out)
		input = _lowpass(input, _master_lp, 0.6)
		out = input.slice(input.size() - out.size())
	out = _softclip(out, _drive)
	var top := 0.0
	for v in out:
		top = maxf(top, absf(v))
	for i in out.size():
		out[i] *= _level / top
	if not _loop:
		var fade := _seconds(0.5)
		for i in fade:
			out[out.size() - 1 - i] *= float(i) / fade
	_write(_name, out)
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




## The round-3 master, in stereo and without the lo-fi: the reverb send goes through a
## convolution hall `room` seconds long (see _hall), the echo bounces a little differently
## on each side, the peaks are hardly touched and the cue is normalised and written.
func _finish_hifi(wet: float, room: float, bright: float) -> void:
	var left := _dry.duplicate()
	var right := _dry_r.duplicate()
	var verb := _convolve(_verb, _verb_r, _hall(room, bright))
	var echoes := []
	for v in _echo:
		if v != 0.0:
			echoes = [_delay(_echo, _step * 6.0, 0.4), _delay(_echo_r, _step * 6.0 + 0.031, 0.4)]
			break
	for i in left.size():
		left[i] += verb[0][i] * wet
		right[i] += verb[1][i] * wet
		if not echoes.is_empty():
			left[i] += echoes[0][i] * 0.5
			right[i] += echoes[1][i] * 0.5
	# Rumble under 45 Hz only muddies small speakers; filtered twice over on a loop, as in _finish.
	for side in [left, right]:
		var input: PackedFloat32Array = side.duplicate()
		if _loop:
			input.append_array(side)
		input = _highpass(input, 45.0, 0.6)
		for i in side.size():
			side[i] = input[input.size() - side.size() + i]
	var out := _interleave(left, right)
	out = _softclip(out, _drive)
	var top := 0.0
	for v in out:
		top = maxf(top, absf(v))
	for i in out.size():
		out[i] *= _level / top
	_write(_name, out, 2)
	_cache.clear()


## A hall for round 3 to play in, made up rather than measured: a few early reflections off
## near walls in the first 80 ms, then a dense tail of noise that dies away (60 dB down after
## `seconds`) and darkens as it does, since air and wood soak up the highs first; it starts
## out low-passed at `bright` Hz. Each ear gets different noise, so the tail is wide. The
## two impulse responses are scaled to unit energy.
func _hall(seconds: float, bright: float) -> Array:
	var irs := []
	var length := seconds * 1.15
	var n := _seconds(length)
	for ch in 2:
		var tail := _noise(length)
		var cut := PackedFloat32Array()
		cut.resize(n)
		var pre := 0.012 + 0.007 * ch
		for i in n:
			var t := float(i) / _rate
			tail[i] *= exp(-6.9 * t / seconds) * smoothstep(pre, pre + 0.08, t)
			cut[i] = 300.0 + bright * exp(-t / (seconds * 0.3))
		tail = _highpass(_filter_swept(tail, "lowpass", cut, 0.6), 70.0, 0.6)
		var early := _silence_samples(n)
		for k in 10:
			var at := rng.randf_range(0.003, 0.08)
			early[_seconds(at)] += (1.0 - at / 0.09) * (1.0 if rng.randf() < 0.5 else -1.0)
		early = _lowpass(early, bright * 1.3, 0.7)
		var ir := _scaled_energy(tail, 0.85)
		_mix(ir, _scaled_energy(early, 0.15), 0, 1.0)
		irs.append(ir)
	return irs


## `x` scaled so the sum of its squares is `energy`.
func _scaled_energy(x: PackedFloat32Array, energy: float) -> PackedFloat32Array:
	var sum := 0.0
	for v in x:
		sum += v * v
	var out := x.duplicate()
	for i in out.size():
		out[i] *= sqrt(energy / sum)
	return out


## Convolves a stereo pair with a pair of impulse responses, left with left and right with
## right, through ffmpeg's afir (convolution is far too slow in GDScript). A loop goes in
## twice and the second pass comes back, so the tail of its end already rings into its start.
func _convolve(left: PackedFloat32Array, right: PackedFloat32Array, irs: Array) -> Array:
	var dir := ProjectSettings.globalize_path("user://music_render/tmp/")
	DirAccess.make_dir_recursive_absolute(dir)
	var l := left.duplicate()
	var r := right.duplicate()
	if _loop:
		l.append_array(left)
		r.append_array(right)
	_write_float_wav(dir + "send.wav", _interleave(l, r))
	_write_float_wav(dir + "hall.wav", _interleave(irs[0], irs[1]))
	var output := []
	var code := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-i", dir + "send.wav", "-i", dir + "hall.wav", "-filter_complex", "[0][1]afir=gtype=none:irnorm=-1:irgain=1[o]", "-map", "[o]", "-f", "f32le", "-c:a", "pcm_f32le", dir + "wet.raw"], output, true)
	if code != 0:
		push_error("ffmpeg could not convolve the reverb (%d): %s" % [code, "".join(output)])
		return [_silence_samples(left.size()), _silence_samples(left.size())]
	var wet := FileAccess.get_file_as_bytes(dir + "wet.raw").to_float32_array()
	var out := [_silence_samples(left.size()), _silence_samples(left.size())]
	var skip := l.size() - left.size()
	for i in left.size():
		out[0][i] = wet[(skip + i) * 2]
		out[1][i] = wet[(skip + i) * 2 + 1]
	return out


func _interleave(left: PackedFloat32Array, right: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(left.size() * 2)
	for i in left.size():
		out[i * 2] = left[i]
		out[i * 2 + 1] = right[i]
	return out


## A 32-bit float stereo WAV, for passing buses to ffmpeg.
func _write_float_wav(path: String, x: PackedFloat32Array) -> void:
	var data := x.to_byte_array()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data.size())
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(3)
	file.store_16(2)
	file.store_32(_rate)
	file.store_32(_rate * 8)
	file.store_16(8)
	file.store_16(32)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data.size())
	file.store_buffer(data)
	file.close()


## Writes a 16-bit WAV (mono, or `channels` interleaved) to user://music_render and encodes
## it to OGG Vorbis in the concepts folder with ffmpeg; without ffmpeg the WAV stays where
## it is.
func _write(cue: String, x: PackedFloat32Array, channels := 1) -> void:
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
	file.store_16(channels)
	file.store_32(_rate)
	file.store_32(_rate * 2 * channels)
	file.store_16(2 * channels)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data.size())
	file.store_buffer(data)
	file.close()
	var ogg := ProjectSettings.globalize_path(ROOT + cue + ".ogg")
	DirAccess.make_dir_recursive_absolute(ogg.get_base_dir())
	var output := []
	var quality := "3" if channels == 1 else "4"
	var code := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", quality, ogg], output, true)
	if code != 0:
		push_warning("ffmpeg failed (%d), left the WAV at %s: %s" % [code, wav, "".join(output)])
