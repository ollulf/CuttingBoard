class_name VoiceBark
extends RefCounted

const PATTERNS := {
	&"hm": [2, 0.85, 1.05, 0.16, 6.0],
	&"mutter": [4, 0.8, 0.75, 0.13, 0.0],
	&"hey": [2, 1.25, 1.35, 0.11, 9.0],
	&"call": [5, 1.15, 1.4, 0.18, 14.0],
	&"answer": [2, 1.1, 1.2, 0.12, 10.0],
}


static func play(source: Node3D, bank: SoundBank, name: StringName, pitch := 1.0) -> void:
	if bank == null or not PATTERNS.has(name) or not source.is_inside_tree():
		return
	var pattern: Array = PATTERNS[name]
	var count: int = pattern[0]
	var volume: float = pattern[4]
	for i in count:
		var t := float(i) / maxf(count - 1, 1)
		var blip_pitch := lerpf(pattern[1], pattern[2], t) * pitch
		if i == 0:
			Sfx.play_at(bank, source.global_position, volume, blip_pitch)
			continue
		source.get_tree().create_timer(pattern[3] * i, true, true).timeout.connect(
			func() -> void:
				if is_instance_valid(source) and source.is_inside_tree():
					Sfx.play_at(bank, source.global_position, volume, blip_pitch)
		)
