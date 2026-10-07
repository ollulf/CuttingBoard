extends "res://tools/audio/synth_base.gd"

## Regenerates every synthesised sound in assets/audio from code, so a sound can be tuned
## by editing its recipe below and running this again:
##
##   godot --headless --path cutting-board -s res://tools/audio/synth_sfx.gd
##   godot --headless --path cutting-board -s res://tools/audio/synth_sfx.gd -- --only=swing,hit_body
##
## then `godot --headless --path cutting-board --import` (or focusing the editor) to
## reimport the changed WAVs.
##
## Everything is made from white noise and sine/saw oscillators shaped by envelopes and
## RBJ biquad filters — no recorded audio. The output is deliberately lo-fi: mono, 16-bit,
## 22 050 Hz, which is about what a PS1 game streamed out of its sound RAM. Each recipe
## is seeded from its own name, so a run reproduces the same files exactly and tuning one
## sound never changes another.
##
## A recipe that writes several numbered takes (step_dirt_1..5) varies its parameters per
## take; the SoundBank resources in resources/audio pick between takes at random and add
## pitch and volume jitter on top.
##
## The ambience loops are rendered a little longer than they play and their tail is
## crossfaded into their head, which makes the seam inaudible; a WAV "smpl" chunk marks
## the loop so Godot imports them looping without touching the import settings.

const ROOT := "res://assets/audio/"


func _init() -> void:
	var only: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	var recipes := {
		# Player and characters.
		"step_dirt": _make_steps,
		"jump": _make_jumps,
		"land": _make_lands,
		"swing": _make_swings,
		"throw": _make_throws,
		"hit_body": _make_body_hits,
		"player_hurt": _make_player_hurts,
		"player_death": _make_player_death,
		"npc_hurt": _make_npc_hurts,
		"npc_death": _make_npc_deaths,
		"body_fall": _make_body_falls,
		"grab": _make_grabs,
		"draw": _make_draws,
		"stow": _make_stows,
		"glue": _make_glue,
		# World.
		"impact_wood": _make_wood_impacts,
		"impact_stone": _make_stone_impacts,
		"break_wood": _make_wood_breaks,
		"break_stone": _make_stone_breaks,
		# Interface.
		"ui": _make_ui,
		# The Mask-Monger's burn ritual.
		"monger_take": _make_monger_takes,
		"monger_toss": _make_monger_tosses,
		"monger_ignite": _make_monger_ignite,
		"monger_soul": _make_monger_soul,
		"monger_cork": _make_monger_corks,
		"monger_clink": _make_monger_clinks,
		"monger_babble": _make_monger_babble,
		"monger_hum_loop": _make_monger_hum,
		# The opening, on the Builder's workbench.
		"intro_room_loop": _make_intro_room,
		"intro_hum": _make_intro_hum,
		"intro_knock": _make_intro_knocks,
		"intro_saw": _make_intro_saw,
		"intro_peg": _make_intro_pegs,
		"intro_plane": _make_intro_plane,
		"intro_mutter": _make_intro_mutter,
		"intro_heart": _make_intro_heart,
		"intro_wind": _make_intro_wind,
		# Ambience.
		"night_loop": _make_night_loop,
		"fair_murmur_loop": _make_fair_murmur,
		"lantern_crackle_loop": _make_lantern_crackle,
	}
	for recipe_name in recipes:
		if not only.is_empty() and not only.has(recipe_name):
			continue
		rng.seed = hash(recipe_name)
		var started := Time.get_ticks_msec()
		(recipes[recipe_name] as Callable).call()
		print("%s  (%d ms)" % [recipe_name, Time.get_ticks_msec() - started])
	quit()


# --- Recipes: characters ------------------------------------------------------------------


## Soft boots on packed earth and grass: a dull heel thump, then the roll onto the toe
## scuffing a little grit. Used for walking, running and crouching alike — the banks
## change only volume and pitch — and for NPCs.
func _make_steps() -> void:
	for take in 5:
		var out := _silence(0.24)
		var heel_freq := rng.randf_range(700.0, 1100.0)
		_mix(out, _shape(_bandpass(_noise(0.08), heel_freq, 0.8), 0.002, 0.035), 0, 0.7)
		_mix(out, _shape(_lowpass(_noise(0.1), 280.0, 0.7), 0.003, 0.05), 0, 1.0)
		_mix(out, _tone(0.08, rng.randf_range(75.0, 95.0), 50.0, 0.04), 0, 0.5)
		var toe := _seconds(rng.randf_range(0.045, 0.075))
		var grit := _grains(_bandpass(_noise(0.12), rng.randf_range(1500.0, 2300.0), 1.0), 0.35, 0.004)
		_mix(out, _shape(grit, 0.004, 0.06), toe, 0.55)
		_mix(out, _shape(_lowpass(_noise(0.06), 400.0, 0.7), 0.003, 0.03), toe, 0.35)
		_save("sfx/step_dirt_%d" % (take + 1), out, 0.9)


## Pushing off: a quick scuff of both feet and a short breath out.
func _make_jumps() -> void:
	for take in 2:
		var out := _silence(0.28)
		_mix(out, _shape(_bandpass(_noise(0.1), rng.randf_range(1000.0, 1400.0), 0.7), 0.004, 0.05), 0, 0.8)
		_mix(out, _shape(_lowpass(_noise(0.08), 300.0, 0.7), 0.003, 0.04), 0, 0.6)
		var breath := _formants(_noise(0.22), [700.0, 1500.0, 2600.0], [1.0, 0.6, 0.2], 4.0)
		_mix(out, _shape(breath, 0.025, 0.11), _seconds(0.02), 0.45)
		_save("sfx/jump_%d" % (take + 1), out, 0.85)


## Both feet coming down at once, with the weight behind them: a heavier thump than a
## step and a longer spray of grit.
func _make_lands() -> void:
	for take in 2:
		var out := _silence(0.4)
		_mix(out, _tone(0.2, rng.randf_range(65.0, 80.0), 38.0, 0.09), 0, 1.0)
		_mix(out, _shape(_lowpass(_noise(0.25), 420.0, 0.7), 0.002, 0.11), 0, 0.9)
		var second := _seconds(rng.randf_range(0.02, 0.04))
		_mix(out, _shape(_bandpass(_noise(0.08), 900.0, 0.8), 0.002, 0.03), second, 0.5)
		var grit := _grains(_bandpass(_noise(0.3), rng.randf_range(1600.0, 2400.0), 1.0), 0.3, 0.004)
		_mix(out, _shape(grit, 0.01, 0.12), _seconds(0.03), 0.5)
		_save("sfx/land_%d" % (take + 1), _softclip(out, 1.4), 0.9)


## A fist cutting the air: band-passed noise whose centre sweeps up and back down while
## its level swells and fades, which is what the ear reads as something passing by.
func _make_swings() -> void:
	for take in 3:
		var length := rng.randf_range(0.18, 0.26)
		var peak := rng.randf_range(1100.0, 1700.0)
		var out := _whoosh(length, 350.0, peak, 500.0, 1.6, 0.4)
		_save("sfx/swing_%d" % (take + 1), out, 0.85)


## A throw: a longer, lower whoosh with the flap of a sleeve in it.
func _make_throws() -> void:
	for take in 2:
		var length := rng.randf_range(0.3, 0.38)
		var out := _whoosh(length, 250.0, rng.randf_range(850.0, 1100.0), 330.0, 1.3, 0.35)
		var flap := _shape(_lowpass(_noise(length), 600.0, 0.7), 0.04, length * 0.3)
		for i in flap.size():
			flap[i] *= 0.6 + 0.4 * sin(TAU * 22.0 * i / sample_rate)
		_mix(out, flap, 0, 0.4)
		_save("sfx/throw_%d" % (take + 1), out, 0.85)


## A blunt blow landing on a body: a deep punchy thump with a slap on top of it and a
## dull mid-range thud, pushed into soft saturation so it hits hard at low volume.
func _make_body_hits() -> void:
	for take in 3:
		var out := _silence(0.26)
		_mix(out, _tone(0.16, rng.randf_range(130.0, 160.0), 52.0, 0.07), 0, 1.0)
		var slap := _highpass(_lowpass(_noise(0.05), rng.randf_range(2400.0, 3400.0), 0.7), 300.0, 0.7)
		_mix(out, _shape(slap, 0.0005, 0.016), 0, 0.9)
		_mix(out, _shape(_bandpass(_noise(0.15), rng.randf_range(220.0, 300.0), 1.0), 0.002, 0.06), 0, 0.8)
		_save("sfx/hit_body_%d" % (take + 1), _softclip(out, 2.2), 0.95)


## The player's own grunts when hit: a rough male voice, short and sharp, on three
## different vowels so repeats do not sound like a sample.
func _make_player_hurts() -> void:
	var vowels := [[640.0, 1190.0, 2390.0], [730.0, 1090.0, 2440.0], [530.0, 1840.0, 2480.0]]
	for take in 3:
		var length := rng.randf_range(0.22, 0.3)
		var f0 := rng.randf_range(125.0, 145.0)
		var out := _voice(length, f0, f0 * 0.78, vowels[take], 0.012, length * 0.45)
		_save("sfx/player_hurt_%d" % (take + 1), out, 0.9)


## The player's last breath: a long falling groan sliding from "ah" towards "oh".
func _make_player_death() -> void:
	var a := _voice(0.9, 120.0, 62.0, [730.0, 1090.0, 2440.0], 0.03, 0.5)
	var o := _voice(0.9, 120.0, 62.0, [570.0, 840.0, 2410.0], 0.03, 0.5)
	var out := _silence(0.9)
	for i in out.size():
		var t := float(i) / out.size()
		out[i] = a[i] * (1.0 - t) + o[i] * t
	_save("sfx/player_death", out, 0.9)


## Villagers and bandits wear masks, so their voices come out of a wooden or cloth face:
## the same grunt as the player's, then dulled by a low-pass and given the hollow ring of
## the mask's cavity.
func _make_npc_hurts() -> void:
	var vowels := [[640.0, 1190.0, 2390.0], [730.0, 1090.0, 2440.0], [530.0, 1840.0, 2480.0], [570.0, 840.0, 2410.0]]
	for take in 4:
		var length := rng.randf_range(0.2, 0.32)
		var f0 := rng.randf_range(105.0, 165.0)
		var out := _voice(length, f0, f0 * rng.randf_range(0.72, 0.85), vowels[take], 0.015, length * 0.45)
		_save("sfx/npc_hurt_%d" % (take + 1), _masked(out), 0.9)


func _make_npc_deaths() -> void:
	for take in 2:
		var f0 := rng.randf_range(110.0, 140.0)
		var out := _voice(0.75, f0, f0 * 0.5, [570.0, 840.0, 2410.0], 0.03, 0.42)
		_save("sfx/npc_death_%d" % (take + 1), _masked(out), 0.9)


## A body hitting the ground: one heavy thump, then the limbs settling after it.
func _make_body_falls() -> void:
	for take in 2:
		var out := _silence(0.55)
		_mix(out, _tone(0.25, rng.randf_range(65.0, 75.0), 40.0, 0.13), 0, 1.0)
		_mix(out, _shape(_lowpass(_noise(0.3), 500.0, 0.7), 0.002, 0.16), 0, 0.9)
		for bump in 2:
			var at := _seconds(rng.randf_range(0.1, 0.25) + bump * 0.1)
			_mix(out, _shape(_lowpass(_noise(0.1), 700.0, 0.7), 0.002, 0.035), at, 0.45 - bump * 0.15)
		_save("sfx/body_fall_%d" % (take + 1), _softclip(out, 1.3), 0.9)


## A hand closing on something: a rustle of sleeve and a light knock of contact.
func _make_grabs() -> void:
	for take in 2:
		var out := _silence(0.16)
		var rustle := _grains(_bandpass(_noise(0.12), rng.randf_range(2200.0, 2900.0), 0.8), 0.6, 0.003)
		_mix(out, _shape(rustle, 0.01, 0.045), 0, 0.7)
		_mix(out, _modes(0.08, [rng.randf_range(280.0, 340.0), 720.0], [0.03, 0.02], [1.0, 0.5]), _seconds(0.02), 0.45)
		_save("sfx/grab_%d" % (take + 1), out, 0.8)


## Pulling an item out of a satchel: leather sliding over leather, rising, and the knock
## of the item settling into the hand.
func _make_draws() -> void:
	for take in 2:
		var length := rng.randf_range(0.22, 0.28)
		var out := _silence(length + 0.06)
		var sweep := _sweep(_noise(length), 1800.0, rng.randf_range(2900.0, 3400.0), 1.2)
		var slide := _grains(sweep, 0.75, 0.002)
		var env := _ramp(slide.size(), 0.85, 0.15)
		for i in slide.size():
			slide[i] *= env[i]
		_mix(out, slide, 0, 0.6)
		_mix(out, _modes(0.07, [220.0, 540.0, 900.0], [0.05, 0.03, 0.02], [1.0, 0.5, 0.3]), _seconds(length - 0.02), 0.5)
		_save("sfx/draw_%d" % (take + 1), out, 0.8)


## The reverse: a falling slide into the bag ending on the soft thump of the bag closing
## round it.
func _make_stows() -> void:
	for take in 2:
		var length := rng.randf_range(0.2, 0.26)
		var out := _silence(length + 0.08)
		var sweep := _sweep(_noise(length), rng.randf_range(2800.0, 3200.0), 1500.0, 1.2)
		var slide := _grains(sweep, 0.75, 0.002)
		var env := _ramp(slide.size(), 0.25, 0.75)
		for i in slide.size():
			slide[i] *= env[i]
		_mix(out, slide, 0, 0.6)
		_mix(out, _shape(_lowpass(_noise(0.1), 320.0, 0.7), 0.003, 0.05), _seconds(length - 0.03), 0.8)
		_save("sfx/stow_%d" % (take + 1), out, 0.8)


## Wood glue worked into a split: a few sticky smears, each a short wet squelch of noise
## sliding down in pitch, then the low creak of the grain drawing back together.
func _make_glue() -> void:
	for take in 2:
		var out := _silence(0.6)
		var at := 0.0
		for smear in rng.randi_range(3, 4):
			var length := rng.randf_range(0.05, 0.08)
			var squelch := _sweep(_noise(length), rng.randf_range(1300.0, 1800.0), rng.randf_range(450.0, 650.0), 4.0)
			_mix(out, _shape(squelch, 0.006, length * 0.35), _seconds(at), rng.randf_range(0.6, 1.0))
			at += rng.randf_range(0.05, 0.09)
		var creak := _grains(_tone(0.28, rng.randf_range(170.0, 200.0), rng.randf_range(115.0, 135.0), 0.25), 0.55, 0.005)
		_mix(out, _shape(creak, 0.04, 0.12), _seconds(at + 0.03), 0.45)
		_save("sfx/glue_%d" % (take + 1), _softclip(out, 1.2), 0.8)


# --- Recipes: world -----------------------------------------------------------------------


## A wooden box or barrel knocking against the ground: the hollow ring of a few wooden
## modes, the click that excites them and the dull thud of the earth under it.
func _make_wood_impacts() -> void:
	for take in 4:
		var f0 := rng.randf_range(150.0, 260.0)
		var out := _silence(0.32)
		_mix(out, _modes(0.3, [f0, f0 * 2.31, f0 * 3.87, f0 * 5.4], [0.12, 0.08, 0.05, 0.035], [1.0, 0.6, 0.4, 0.25]), 0, 0.8)
		_mix(out, _shape(_lowpass(_noise(0.02), 4000.0, 0.7), 0.0003, 0.004), 0, 0.6)
		_mix(out, _shape(_lowpass(_noise(0.12), 250.0, 0.7), 0.002, 0.05), 0, 0.7)
		_save("sfx/impact_wood_%d" % (take + 1), _softclip(out, 1.3), 0.9)


## A rock: a bright click with a short stony ring, on top of the thud of it hitting
## earth.
func _make_stone_impacts() -> void:
	for take in 4:
		var f0 := rng.randf_range(1050.0, 1600.0)
		var out := _silence(0.2)
		_mix(out, _shape(_highpass(_noise(0.03), 1500.0, 0.7), 0.0002, 0.006), 0, 0.8)
		_mix(out, _modes(0.12, [f0, f0 * 1.73, f0 * 2.61], [0.025, 0.018, 0.012], [1.0, 0.6, 0.4]), 0, 0.5)
		_mix(out, _shape(_lowpass(_noise(0.1), 220.0, 0.7), 0.002, 0.04), 0, 0.8)
		_save("sfx/impact_stone_%d" % (take + 1), out, 0.9)


## A crate or barrel giving way: one big crunch, a run of cracks that get smaller as it
## comes apart, and splinters pattering down afterwards.
func _make_wood_breaks() -> void:
	for take in 2:
		var out := _silence(0.85)
		_mix(out, _tone(0.2, 95.0, 48.0, 0.12), 0, 0.9)
		_mix(out, _shape(_lowpass(_noise(0.2), 1500.0, 0.7), 0.001, 0.09), 0, 0.9)
		var at := 0.0
		var loud := 1.0
		for crack in rng.randi_range(6, 9):
			at += rng.randf_range(0.015, 0.07)
			var crunch := _shape(_bandpass(_noise(0.05), rng.randf_range(800.0, 3000.0), 1.5), 0.0005, rng.randf_range(0.008, 0.02))
			_mix(out, crunch, _seconds(at), 0.8 * loud)
			var f0 := rng.randf_range(200.0, 500.0)
			_mix(out, _modes(0.08, [f0, f0 * 2.4], [0.04, 0.025], [1.0, 0.5]), _seconds(at), 0.5 * loud)
			loud *= 0.82
		for splinter in 14:
			var when := rng.randf_range(0.12, 0.75)
			var click := _shape(_highpass(_noise(0.01), 2500.0, 0.7), 0.0002, 0.003)
			_mix(out, click, _seconds(when), rng.randf_range(0.1, 0.35) * (1.0 - when))
		_save("sfx/break_wood_%d" % (take + 1), _softclip(out, 1.5), 0.95)


## A thrown rock splitting: a hard crack and a spill of gravel.
func _make_stone_breaks() -> void:
	for take in 2:
		var out := _silence(0.5)
		_mix(out, _shape(_highpass(_noise(0.06), 800.0, 0.7), 0.0003, 0.025), 0, 1.0)
		_mix(out, _shape(_lowpass(_noise(0.1), 250.0, 0.7), 0.002, 0.05), 0, 0.8)
		for chip in 12:
			var when := rng.randf_range(0.01, 0.4)
			var f0 := rng.randf_range(1500.0, 3500.0)
			var ring := _modes(0.03, [f0, f0 * 1.6], [0.01, 0.007], [1.0, 0.5])
			_mix(out, ring, _seconds(when), rng.randf_range(0.15, 0.5) * (1.0 - when * 2.0))
		_save("sfx/break_stone_%d" % (take + 1), out, 0.9)


# --- Recipes: interface -------------------------------------------------------------------


## The inventory sounds. The screen is the satchel, so opening and closing it are a
## leather flap and a buckle; items being moved about in it are small wooden tocks.
func _make_ui() -> void:
	# Opening: the buckle clinks, the flap lifts with a rustle and a soft thump.
	var open := _silence(0.26)
	_mix(open, _modes(0.05, [2600.0, 4100.0], [0.03, 0.02], [1.0, 0.6]), 0, 0.25)
	var rustle := _grains(_bandpass(_noise(0.2), 2200.0, 1.0), 0.7, 0.003)
	_mix(open, _shape(rustle, 0.015, 0.08), _seconds(0.02), 0.6)
	_mix(open, _shape(_lowpass(_noise(0.1), 400.0, 0.7), 0.003, 0.04), _seconds(0.06), 0.7)
	_save("ui/ui_bag_open", open, 0.75)

	# Closing: the flap comes down first, then the buckle.
	var close := _silence(0.24)
	_mix(close, _shape(_lowpass(_noise(0.1), 380.0, 0.7), 0.002, 0.045), 0, 0.8)
	var rustle_short := _grains(_bandpass(_noise(0.12), 1900.0, 1.0), 0.7, 0.003)
	_mix(close, _shape(rustle_short, 0.005, 0.05), 0, 0.5)
	_mix(close, _modes(0.06, [2400.0, 3900.0], [0.03, 0.02], [1.0, 0.6]), _seconds(0.12), 0.25)
	_save("ui/ui_bag_close", close, 0.75)

	# Setting an item down in the grid.
	var place := _silence(0.1)
	_mix(place, _modes(0.1, [520.0, 1310.0, 2150.0], [0.04, 0.025, 0.015], [1.0, 0.5, 0.3]), 0, 0.8)
	_mix(place, _shape(_lowpass(_noise(0.01), 3000.0, 0.7), 0.0002, 0.003), 0, 0.4)
	_save("ui/ui_place", place, 0.7)

	# Putting something on or into a hand: a lower tock with a small metal chink.
	var equip := _silence(0.2)
	_mix(equip, _modes(0.1, [380.0, 960.0], [0.05, 0.03], [1.0, 0.5]), 0, 0.8)
	_mix(equip, _modes(0.18, [2400.0, 3610.0, 5100.0], [0.06, 0.04, 0.03], [1.0, 0.6, 0.4]), _seconds(0.015), 0.3)
	_save("ui/ui_equip", equip, 0.7)

	# Refused: two short low buzzes.
	var invalid := _silence(0.17)
	for blip in 2:
		var buzz := _lowpass(_square(0.055, 140.0), 900.0, 0.7)
		_mix(invalid, _shape(buzz, 0.003, 0.03), _seconds(blip * 0.08), 1.0)
	_save("ui/ui_invalid", invalid, 0.6)

	# An item let go out of the window and into the world: a small falling swish.
	_save("ui/ui_drop", _whoosh(0.14, 1300.0, 1100.0, 500.0, 1.4, 0.2), 0.6)


# --- Recipes: ambience --------------------------------------------------------------------


## The night outside: a low wind that rises and falls, a few crickets near by and a
## field of them far off.
func _make_night_loop() -> void:
	var loop := 16.0
	var fade := 1.5
	var length := loop + fade
	var n := _seconds(length)

	# Wind: brown noise, its low-pass opening and closing on slow sines that fit a whole
	# number of times into the loop, so only the noise itself needs the crossfade.
	var brown := _brown(length)
	var cutoffs := PackedFloat32Array()
	cutoffs.resize(n)
	var level := PackedFloat32Array()
	level.resize(n)
	for i in n:
		var t := float(i) / sample_rate
		var gust := 0.5 * sin(TAU * t / loop) + 0.3 * sin(TAU * 2.0 * t / loop + 1.3) + 0.2 * sin(TAU * 5.0 * t / loop + 0.4)
		cutoffs[i] = 420.0 + 220.0 * gust
		level[i] = 0.75 + 0.25 * gust
	var wind := _filter_swept(brown, "lowpass", cutoffs, 0.9)
	var out := _silence(length)
	for i in n:
		out[i] = wind[i] * level[i] * 0.7

	# Crickets: each chirp a few short pulses of a high tone, repeated at the cricket's
	# own rate, now and then skipping a beat. Farther crickets are quieter and duller.
	var crickets := [[4200.0, 0.62, 0.11, 4], [4550.0, 0.85, 0.07, 3], [3850.0, 1.15, 0.05, 4]]
	for cricket in crickets:
		var at := rng.randf_range(0.0, 0.5)
		while at < length - 0.2:
			if rng.randf() > 0.15:
				_mix(out, _chirp(cricket[0] * rng.randf_range(0.99, 1.01), cricket[3]), _seconds(at), cricket[2])
			at += cricket[1] * rng.randf_range(0.9, 1.1)
	# The far field: a narrow band of noise around cricket pitch with a slow shimmer.
	var field := _bandpass(_noise(length), 4300.0, 6.0)
	for i in n:
		field[i] *= 0.6 + 0.4 * sin(TAU * 3.0 * i / sample_rate / 2.0)
	_mix(out, field, 0, 0.06)

	_save_loop("ambience/night_loop", out, loop, fade, 0.6)


## A crowd at the fair, heard from a distance: a handful of voices talking over each
## other in syllables with no words, muffled by the distance and smeared by the houses.
func _make_fair_murmur() -> void:
	var loop := 12.0
	var fade := 1.0
	var length := loop + fade
	var out := _silence(length)
	var vowels := [[730.0, 1090.0, 2440.0], [530.0, 1840.0, 2480.0], [270.0, 2290.0, 3010.0], [570.0, 840.0, 2410.0], [640.0, 1190.0, 2390.0], [300.0, 870.0, 2240.0]]
	for speaker in 9:
		var base := rng.randf_range(95.0, 230.0)
		var gain := rng.randf_range(0.4, 1.0)
		var at := rng.randf_range(0.0, 1.5)
		while at < length - 0.4:
			# A phrase: a run of syllables with the pitch drifting through it, then a pause.
			var syllables := rng.randi_range(3, 9)
			var pitch := base * rng.randf_range(0.95, 1.15)
			for s in syllables:
				var dur := rng.randf_range(0.1, 0.25)
				if at + dur > length:
					break
				var vowel: Array = vowels[rng.randi_range(0, vowels.size() - 1)]
				var syl := _voice(dur, pitch, pitch * rng.randf_range(0.9, 1.05), vowel, 0.02, dur * 0.35)
				_mix(out, syl, _seconds(at), gain * rng.randf_range(0.6, 1.0))
				pitch *= rng.randf_range(0.94, 1.03)
				at += dur + rng.randf_range(0.02, 0.12)
			at += rng.randf_range(0.4, 1.8)
	out = _lowpass(out, 950.0, 0.7)
	# A couple of short echoes off the houses.
	var smear := out.duplicate()
	_mix(out, smear, _seconds(0.043), 0.35)
	_mix(out, smear, _seconds(0.091), 0.2)
	_save_loop("ambience/fair_murmur_loop", out, loop, fade, 0.6)


## A lantern's flame: a faint low flutter and the odd crackle, most of them tiny and a
## few sharp.
func _make_lantern_crackle() -> void:
	var loop := 8.0
	var fade := 0.5
	var length := loop + fade
	var n := _seconds(length)
	var out := _lowpass(_brown(length), 160.0, 0.7)
	for i in n:
		var t := float(i) / sample_rate
		out[i] *= 0.5 * (0.7 + 0.3 * sin(TAU * 1.0 * t / loop * 8.0) * sin(TAU * 3.0 * t / loop))
	var at := 0.0
	while at < length - 0.05:
		at += -log(maxf(rng.randf(), 0.0001)) / 7.0
		var size := pow(rng.randf(), 3.0)
		for click in rng.randi_range(1, 3):
			var crack := _shape(_highpass(_noise(0.01), 2000.0, 0.7), 0.0001, rng.randf_range(0.0015, 0.004))
			_mix(out, crack, _seconds(at + click * rng.randf_range(0.004, 0.012)), 0.15 + 0.85 * size)
		if size > 0.5:
			var sizzle := _shape(_bandpass(_noise(0.05), 3500.0, 1.0), 0.002, 0.025)
			_mix(out, sizzle, _seconds(at), 0.2 * size)
	_save_loop("ambience/lantern_crackle_loop", out, loop, fade, 0.6)


## The Mask-Monger's puppet humming to itself, heard while the player is bare-faced so the
## Monger can be found by ear: a slow lullaby in A minor, a hummed "mm" (a sine with soft
## second and third partials, a little vibrato) behind a closed mouth (lowpass).
func _make_monger_hum() -> void:
	var loop := 9.6
	var fade := 0.4
	var length := loop + fade
	var out := _silence(length)
	# [semitones above A3, start beat, beats]; 0.6 s a beat, 16 beats a loop.
	var tune := [[7, 0, 2], [10, 2, 1], [12, 3, 1], [10, 4, 2], [7, 6, 2],
			[5, 8, 2], [3, 10, 1], [5, 11, 1], [7, 12, 3], [0, 15, 1]]
	for note: Array in tune:
		var freq := 220.0 * pow(2.0, float(note[0]) / 12.0)
		var dur: float = note[2] * 0.6 + 0.25
		var n := _seconds(dur)
		var x := PackedFloat32Array()
		x.resize(n)
		var phase := rng.randf() * TAU
		for i in n:
			var t := float(i) / sample_rate
			phase += TAU * freq * (1.0 + 0.006 * sin(TAU * 5.0 * t)) / sample_rate
			var env := minf(1.0, t / 0.12) * minf(1.0, (dur - t) / 0.25)
			x[i] = (sin(phase) + 0.3 * sin(2.0 * phase) + 0.12 * sin(3.0 * phase)) * env
		_mix(out, x, _seconds(float(note[1]) * 0.6), 1.0)
	out = _lowpass(out, 900.0, 0.7)
	_save_loop("sfx/monger_hum_loop", out, loop, fade, 0.5)


# --- Recipes: the Mask-Monger's burn ritual -----------------------------------------------


## The puppet snatching the mask: two quick hollow wooden clacks, like a puppet's jaw
## snapping shut on it.
func _make_monger_takes() -> void:
	for take in 2:
		var out := _silence(0.24)
		for hit in 2:
			var f0 := rng.randf_range(380.0, 520.0) * (1.25 if hit == 1 else 1.0)
			var at := _seconds(0.07 * hit)
			_mix(out, _modes(0.14, [f0, f0 * 2.7, f0 * 4.9], [0.05, 0.03, 0.015], [1.0, 0.5, 0.3]), at, 0.8 - hit * 0.2)
			_mix(out, _shape(_bandpass(_noise(0.02), 2500.0, 1.0), 0.0003, 0.006), at, 0.7)
		_save("sfx/monger_take_%d" % (take + 1), _softclip(out, 1.3), 0.9)


## Flinging the mask up: a whoosh that rises in pitch as it climbs, with the wobble of a
## spinning thing in it.
func _make_monger_tosses() -> void:
	for take in 2:
		var length := rng.randf_range(0.42, 0.5)
		var out := _whoosh(length, 300.0, rng.randf_range(1400.0, 1800.0), 1900.0, 1.4, 0.55)
		for i in out.size():
			out[i] *= 0.65 + 0.35 * sin(TAU * 14.0 * i / sample_rate)
		_save("sfx/monger_toss_%d" % (take + 1), out, 0.8)


## The lantern catching the mask: a soft low whump of air drawn in, then a dry crackle
## of wood shavings catching that thins out.
func _make_monger_ignite() -> void:
	var out := _silence(1.1)
	var whump := _filter_swept(_noise(0.35), "lowpass", _glide_freqs(0.35, 120.0, 700.0), 0.9)
	_mix(out, _shape(whump, 0.03, 0.14), 0, 1.0)
	_mix(out, _tone(0.3, 90.0, 55.0, 0.15), 0, 0.6)
	var crackle := _grains(_highpass(_noise(1.0), 1800.0, 0.7), 0.25, 0.003)
	_mix(out, _shape(crackle, 0.05, 0.35), _seconds(0.08), 0.7)
	var pops := _grains(_bandpass(_noise(1.0), 900.0, 1.2), 0.04, 0.008)
	_mix(out, _shape(pops, 0.05, 0.3), _seconds(0.1), 0.6)
	_save("sfx/monger_ignite", _softclip(out, 1.2), 0.9)


## The soul spiralling down into the vial: a breathy ghost whistle that swoops up and
## warbles, like blowing over a bottle; eerie but silly.
func _make_monger_soul() -> void:
	var length := 1.3
	var n := _seconds(length)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var freq := lerpf(520.0, 1150.0, sin(t * PI * 0.5)) * (1.0 + 0.04 * sin(TAU * 6.0 * i / sample_rate))
		phase += TAU * freq / sample_rate
		out[i] = sin(phase) * pow(sin(t * PI), 0.7)
	var air := _filter_swept(_noise(length), "bandpass", _glide_freqs(length, 520.0, 1150.0), 6.0)
	for i in n:
		air[i] *= pow(sin(float(i) / n * PI), 0.7)
	_mix(out, air, 0, 1.4)
	_save("sfx/monger_soul", out, 0.7)


## The cork going into the vial: the pop of a small cavity with a quick upward flick.
func _make_monger_corks() -> void:
	for take in 2:
		var out := _silence(0.16)
		_mix(out, _tone(0.1, rng.randf_range(380.0, 460.0), rng.randf_range(900.0, 1100.0), 0.03), 0, 0.9)
		_mix(out, _shape(_bandpass(_noise(0.03), 1800.0, 1.2), 0.0005, 0.008), 0, 0.6)
		_save("sfx/monger_cork_%d" % (take + 1), out, 0.85)


## The vial landing at the giver's feet: a small thud under a bright glassy clink, and a
## second smaller one as it settles.
func _make_monger_clinks() -> void:
	for take in 2:
		var out := _silence(0.5)
		var f0 := rng.randf_range(2300.0, 2900.0)
		_mix(out, _shape(_lowpass(_noise(0.08), 300.0, 0.7), 0.002, 0.03), 0, 0.6)
		_mix(out, _modes(0.4, [f0, f0 * 1.58, f0 * 2.43], [0.12, 0.08, 0.05], [1.0, 0.5, 0.3]), 0, 0.6)
		_mix(out, _modes(0.3, [f0 * 1.05, f0 * 1.6], [0.08, 0.05], [1.0, 0.4]), _seconds(rng.randf_range(0.11, 0.15)), 0.3)
		_save("sfx/monger_clink_%d" % (take + 1), out, 0.85)


## The puppet's voice: squeaky blips of babble, a few quick syllables bouncing in pitch
## (takes 1-2), and a rising "ooh!" gasp for the flare (take 3, played on its own).
func _make_monger_babble() -> void:
	var vowels := [[300.0, 2300.0, 3000.0], [700.0, 1200.0, 2600.0], [450.0, 900.0, 2600.0], [550.0, 1800.0, 2600.0]]
	for take in 2:
		var out := _silence(0.7)
		var at := 0
		for syl in rng.randi_range(4, 5):
			var f0 := rng.randf_range(330.0, 480.0)
			var length := rng.randf_range(0.07, 0.11)
			var v: Array = vowels[rng.randi() % vowels.size()]
			_mix(out, _voice(length, f0, f0 * rng.randf_range(0.8, 1.3), v, 0.008, length * 0.6), at, 0.8)
			at += _seconds(length + rng.randf_range(0.01, 0.03))
		_save("sfx/monger_babble_%d" % (take + 1), out, 0.8)
	var gasp := _silence(0.5)
	_mix(gasp, _voice(0.42, 300.0, 620.0, [450.0, 900.0, 2600.0], 0.03, 0.2), 0, 1.0)
	_save("sfx/monger_gasp", gasp, 0.8)


# --- Recipes: the opening -----------------------------------------------------------------
# Heard lying on the Builder's workbench in the dark (IntroSequence): warm, a little goofy
# woodwork, never horror. The opening places each one around the camera itself.


## The workshop's room tone: a low, close brown-noise hush with a faint warm hum of the
## room in it, looping under the whole dark.
func _make_intro_room() -> void:
	var loop := 8.0
	var fade := 1.0
	var length := loop + fade
	var n := _seconds(length)
	var out := _lowpass(_brown(length), 260.0, 0.7)
	var air := _bandpass(_noise(length), 900.0, 0.8)
	for i in n:
		var t := float(i) / sample_rate
		out[i] = out[i] * (0.85 + 0.15 * sin(TAU * t / loop)) + air[i] * 0.04 + sin(TAU * 98.0 * t) * 0.015
	_save_loop("ambience/intro_room_loop", out, loop, fade, 0.5)


## The Builder humming at the work: a cheerful wordless "mm-hm-hmm" tune with a lip-closed
## vowel, a few notes bobbing up and down.
func _make_intro_hum() -> void:
	var hum_vowel := [250.0, 900.0, 2200.0]
	var tunes := [[196.0, 220.0, 247.0, 220.0, 262.0], [262.0, 247.0, 220.0, 196.0, 220.0, 196.0]]
	for take in tunes.size():
		var notes: Array = tunes[take]
		var out := _silence(0.56 * notes.size() + 0.5)
		var at := 0.0
		for note in notes:
			var length := rng.randf_range(0.28, 0.48)
			var f0: float = note * 0.75
			var voiced := _lowpass(_voice(length, f0 * 0.97, f0 * rng.randf_range(1.0, 1.04), hum_vowel, 0.04, length * 0.8), 900.0, 0.7)
			_mix(out, voiced, _seconds(at), rng.randf_range(0.7, 1.0))
			at += length + rng.randf_range(0.0, 0.06)
		_save("sfx/intro_hum_%d" % (take + 1), out, 0.8)


## Knuckles knocking on a wooden board, twice: a hollow ring of a few modes with a click.
func _make_intro_knocks() -> void:
	for take in 2:
		var out := _silence(0.7)
		for k in 2:
			var at := _seconds(k * rng.randf_range(0.16, 0.2))
			var f0 := rng.randf_range(230.0, 270.0)
			_mix(out, _modes(0.25, [f0, f0 * 2.3, f0 * 3.9], [0.07, 0.03, 0.015], [1.0, 0.45, 0.2]), at, 0.9)
			_mix(out, _shape(_bandpass(_noise(0.02), 2500.0, 1.0), 0.001, 0.006), at, 0.4)
		_save("sfx/intro_knock_%d" % (take + 1), out, 0.85)


## A handsaw going through a plank: rasping strokes back and forth, each a band of noise
## chopped by the teeth, the push brighter than the pull.
func _make_intro_saw() -> void:
	var out := _silence(2.6)
	var at := 0.0
	for stroke in 6:
		var length := rng.randf_range(0.3, 0.38)
		var push := stroke % 2 == 0
		var rasp := _bandpass(_noise(length), 2400.0 if push else 1700.0, 1.6)
		var teeth := 90.0 if push else 70.0
		for i in rasp.size():
			rasp[i] *= 0.4 + 0.6 * absf(sin(PI * teeth * i / sample_rate))
		_mix(out, _shape(rasp, length * 0.3, length * 0.4), _seconds(at), 1.0 if push else 0.7)
		_mix(out, _shape(_lowpass(_noise(length), 300.0, 0.7), length * 0.3, length * 0.4), _seconds(at), 0.35)
		at += length + 0.03
	_save("sfx/intro_saw", out, 0.8)


## A wooden peg tapped home with a mallet: three taps, each a little higher as the peg
## seats. intro_peg_last is the last peg: one firm, satisfied tap that rings longer.
func _make_intro_pegs() -> void:
	for take in 2:
		var out := _silence(0.9)
		var f0 := rng.randf_range(380.0, 440.0)
		for tap in 3:
			var at := _seconds(tap * rng.randf_range(0.2, 0.26))
			_mix(out, _modes(0.18, [f0, f0 * 2.7], [0.045, 0.02], [1.0, 0.4]), at, 0.8)
			_mix(out, _tone(0.1, 140.0, 90.0, 0.03), at, 0.5)
			f0 *= 1.08
		_save("sfx/intro_peg_%d" % (take + 1), out, 0.8)
	var last := _silence(1.4)
	_mix(last, _modes(1.2, [520.0, 520.0 * 2.6, 520.0 * 4.1], [0.35, 0.12, 0.05], [1.0, 0.4, 0.2]), 0, 0.9)
	_mix(last, _tone(0.3, 120.0, 70.0, 0.08), 0, 0.7)
	_save("sfx/intro_peg_last", last, 0.85)


## A hand plane shaving a board: two long breathy hisses that brighten as the blade
## bites, with a curl of shaving crackling off the top.
func _make_intro_plane() -> void:
	var out := _silence(2.2)
	var at := 0.0
	for stroke in 2:
		var length := rng.randf_range(0.6, 0.75)
		var hiss := _sweep(_noise(length), 1800.0, 4200.0, 1.2)
		_mix(out, _shape(hiss, 0.08, length * 0.35), _seconds(at), 0.9)
		var curl := _grains(_bandpass(_noise(length), 3000.0, 1.0), 0.15, 0.003)
		_mix(out, _shape(curl, 0.1, length * 0.3), _seconds(at + 0.1), 0.35)
		at += length + rng.randf_range(0.25, 0.35)
	_save("sfx/intro_plane", out, 0.75)


## The Builder muttering over the work: low, quick, wordless syllables, then a pleased
## little "hm!".
func _make_intro_mutter() -> void:
	var vowels := [[500.0, 1100.0, 2400.0], [400.0, 900.0, 2400.0], [600.0, 1300.0, 2500.0]]
	for take in 2:
		var out := _silence(1.8)
		var at := 0
		for syl in rng.randi_range(5, 7):
			var f0 := rng.randf_range(110.0, 150.0)
			var length := rng.randf_range(0.08, 0.14)
			var v: Array = vowels[rng.randi() % vowels.size()]
			_mix(out, _voice(length, f0, f0 * rng.randf_range(0.85, 1.1), v, 0.01, length * 0.6), at, 0.8)
			at += _seconds(length + rng.randf_range(0.02, 0.06))
		at += _seconds(0.15)
		_mix(out, _lowpass(_voice(0.25, 130.0, 175.0, [250.0, 900.0, 2200.0], 0.02, 0.15), 900.0, 0.7), at, 1.0)
		_save("sfx/intro_mutter_%d" % (take + 1), out, 0.8)


## The heart-knock from inside: a woody "lub-dub", two low hollow thumps close together,
## felt more than heard.
func _make_intro_heart() -> void:
	var out := _silence(0.7)
	for beat in 2:
		var at := _seconds(beat * 0.17)
		var f0 := 72.0 if beat == 0 else 82.0
		_mix(out, _modes(0.45, [f0, f0 * 2.2, f0 * 3.6], [0.12, 0.05, 0.025], [1.0, 0.35, 0.15]), at, 1.0 if beat == 0 else 0.7)
		_mix(out, _tone(0.3, 110.0, 50.0, 0.05), at, 0.8)
		_mix(out, _shape(_bandpass(_noise(0.02), 1400.0, 1.0), 0.001, 0.008), at, 0.15)
	_save("sfx/intro_heart", _softclip(out, 1.3), 0.9)


## Falling: wind rising over eight seconds from a far whisper to a roaring rush, its band
## climbing and fluttering as the speed builds.
func _make_intro_wind() -> void:
	var length := 8.0
	var n := _seconds(length)
	var cutoffs := PackedFloat32Array()
	cutoffs.resize(n)
	for i in n:
		var t := float(i) / n
		cutoffs[i] = lerpf(300.0, 1600.0, t * t) * (1.0 + 0.15 * sin(TAU * 3.1 * i / sample_rate) * t)
	var rush := _filter_swept(_noise(length), "bandpass", cutoffs, 0.9)
	var body := _lowpass(_brown(length), 220.0, 0.7)
	var out := _silence(length)
	var tail := float(_seconds(0.05))
	for i in n:
		var t := float(i) / n
		var swell := pow(t, 1.6)
		out[i] = (rush[i] * 0.8 + body[i] * 0.6) * (0.08 + 0.92 * swell) * minf(1.0, (n - i) / tail)
	_save("sfx/intro_wind", out, 0.85)


# --- Building blocks ----------------------------------------------------------------------


## A swept band-pass whoosh: the centre glides from `start` to `peak` at `peak_at`
## (0..1 of the length) and on to `end`, while the level swells and dies away with it.
func _whoosh(length: float, start: float, peak: float, end: float, q: float, peak_at: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var freqs := PackedFloat32Array()
	freqs.resize(n)
	var env := PackedFloat32Array()
	env.resize(n)
	for i in n:
		var t := float(i) / n
		if t < peak_at:
			var u := t / peak_at
			freqs[i] = lerpf(start, peak, u * u)
			env[i] = pow(sin(u * PI * 0.5), 2.0)
		else:
			var u := (t - peak_at) / (1.0 - peak_at)
			freqs[i] = lerpf(peak, end, sqrt(u))
			env[i] = pow(cos(u * PI * 0.5), 1.5)
	var out := _filter_swept(_noise(length), "bandpass", freqs, q)
	for i in n:
		out[i] *= env[i]
	return out


## A voice: a sawtooth glottal source gliding from `f0_from` to `f0_to`, with a little
## pitch jitter and a growl at half the pitch for roughness, shaped by three formants for
## the vowel and given a breath of aspiration noise. `attack` is the onset time; the rest
## of the sound falls away over `decay`.
func _voice(length: float, f0_from: float, f0_to: float, vowel: Array, attack: float, decay: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var source := PackedFloat32Array()
	source.resize(n)
	var phase := 0.0
	var drift := 0.0
	for i in n:
		var t := float(i) / n
		drift = clampf(drift + rng.randf_range(-0.004, 0.004), -0.04, 0.04)
		var f0 := lerpf(f0_from, f0_to, t) * (1.0 + drift)
		phase += f0 / sample_rate
		var growl := 0.75 + 0.25 * signf(sin(PI * phase))
		source[i] = (2.0 * fposmod(phase, 1.0) - 1.0) * growl
	var breath := _noise(length)
	for i in n:
		source[i] += breath[i] * 0.18
	var voiced := _formants(source, vowel, [1.0, 0.5, 0.2], 9.0)
	return _shape(voiced, attack, decay)


## The muffling of a mask: a low-pass dulls the voice and a peak around 450 Hz adds the
## boxy ring of the space between face and mask.
func _masked(voice: PackedFloat32Array) -> PackedFloat32Array:
	var dull := _lowpass(voice, 1100.0, 0.7)
	var ring := _bandpass(voice, 450.0, 3.0)
	_mix(dull, ring, 0, 0.6)
	return dull


## A cricket's chirp: `pulses` short pulses of a tone, 22 ms apart.
func _chirp(freq: float, pulses: int) -> PackedFloat32Array:
	var out := _silence(0.022 * pulses + 0.02)
	var pulse_len := _seconds(0.013)
	for p in pulses:
		var start := _seconds(0.022 * p)
		for i in pulse_len:
			var env := pow(sin(PI * float(i) / pulse_len), 2.0)
			out[start + i] += sin(TAU * freq * (start + i) / sample_rate) * env
	return out


## A tone gliding exponentially from `from` to `to` Hz over `glide` seconds, decaying
## away to nothing by the end of `length`.
func _tone(length: float, from: float, to: float, glide: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / sample_rate
		var freq := to + (from - to) * exp(-t / maxf(glide * 0.4, 0.001))
		phase += TAU * freq / sample_rate
		out[i] = sin(phase) * exp(-t / (length * 0.3)) * minf(1.0, t / 0.002)
	return out


## Modal synthesis: a struck object as a sum of exponentially decaying sines.
func _modes(length: float, freqs: Array, decays: Array, amps: Array) -> PackedFloat32Array:
	var n := _seconds(length)
	var out := PackedFloat32Array()
	out.resize(n)
	for m in freqs.size():
		var freq: float = freqs[m] * rng.randf_range(0.98, 1.02)
		var decay: float = decays[m]
		var amp: float = amps[m]
		var phase := rng.randf() * TAU
		for i in n:
			var t := float(i) / sample_rate
			out[i] += sin(phase + TAU * freq * t) * exp(-t / decay) * amp * minf(1.0, t / 0.0005)
	return out


func _square(length: float, freq: float) -> PackedFloat32Array:
	var n := _seconds(length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = 1.0 if fposmod(freq * i / sample_rate, 1.0) < 0.5 else -1.0
	return out


## Brown (red) noise: leaky-integrated white noise, all rumble and no hiss.
func _brown(length: float) -> PackedFloat32Array:
	var out := _noise(length)
	var acc := 0.0
	for i in out.size():
		acc = acc * 0.995 + out[i] * 0.1
		out[i] = acc
	return out


## Chops a signal into random short grains — `density` of them kept — which turns smooth
## noise into grit, gravel or the crackle of cloth. Each grain is faded in and out, so
## the chopping itself adds no clicks of its own.
func _grains(x: PackedFloat32Array, density: float, grain: float) -> PackedFloat32Array:
	var size := maxi(_seconds(grain), 2)
	var out := x.duplicate()
	var i := 0
	while i < out.size():
		var keep := rng.randf() < density
		var gain := rng.randf_range(0.4, 1.0) if keep else 0.0
		for j in range(i, mini(i + size, out.size())):
			out[j] *= gain * pow(sin(PI * float(j - i) / size), 2.0)
		i += size
	return out


## Band-pass noise sweeping from `from` to `to` Hz across its length.
func _sweep(x: PackedFloat32Array, from: float, to: float, q: float) -> PackedFloat32Array:
	var freqs := PackedFloat32Array()
	freqs.resize(x.size())
	for i in x.size():
		freqs[i] = lerpf(from, to, float(i) / x.size())
	return _filter_swept(x, "bandpass", freqs, q)


# --- Output -------------------------------------------------------------------------------


## Normalises a one-shot to `peak`, fades its last few milliseconds so it never ends on a
## click, and writes it.
func _save(path: String, x: PackedFloat32Array, peak: float) -> void:
	var out := _normalized(x, peak)
	var fade := mini(_seconds(0.01), out.size())
	for i in fade:
		out[out.size() - 1 - i] *= float(i) / fade
	_write_wav(ROOT + path + ".wav", out, false)


## Folds the last `fade` seconds of a buffer rendered `loop + fade` long back over its
## start with an equal-power crossfade, so the loop point is seamless, and writes it
## marked as a loop.
func _save_loop(path: String, x: PackedFloat32Array, loop: float, fade: float, peak: float) -> void:
	var n := _seconds(loop)
	var f := _seconds(fade)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = x[i]
	for i in f:
		var t := float(i) / f
		out[i] = x[i] * sqrt(t) + x[n + i] * sqrt(1.0 - t)
	_write_wav(ROOT + path + ".wav", _normalized(out, peak), true)
