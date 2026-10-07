class_name FieldAudio
extends Node
## Short original synthesized UI/combat cues, plus the generated warehouse cues
## (audio/sfx/, cut by audio/tools/cut_audio.py). A file cue whose file does not
## exist yet stays silent but is still counted.
## cue -> [path, volume dB, random pitch spread]
const FILE_CUES := {
	"lights_on": ["res://audio/sfx/lights_on.wav", -8.0, 0.0],
	"lights_off": ["res://audio/sfx/lights_off.wav", -8.0, 0.0],
	"hatch": ["res://audio/sfx/hatch.wav", -14.0, 0.05],
	"shelf": ["res://audio/sfx/shelf.wav", -16.0, 0.05],
}
var streams := {}
## How many times each cue was asked for, headless included (tests count events).
var counts := {}
func _ready() -> void:
	GameMusic.ensure_buses()
	for cue in FILE_CUES:
		if ResourceLoader.exists(FILE_CUES[cue][0]): streams[cue] = load(FILE_CUES[cue][0])
	for cue in {"hit": 170.0, "loot": 660.0, "build": 880.0, "exit": 1040.0, "hurt": 110.0, "charge": 1760.0}:
		var frequencies := {"hit": 170.0, "loot": 660.0, "build": 880.0, "exit": 1040.0, "hurt": 110.0, "charge": 1760.0}
		var data := PackedByteArray()
		for i in range(4410):
			var envelope := 1.0 - float(i) / 4410.0
			var time := float(i) / 22050.0
			var tone := sin(time * TAU * float(frequencies[cue]))
			if cue == "charge":
				envelope = exp(-time * 32.0)
				tone = tone * 0.55 + sin(time * TAU * 4860.0) * 0.3 + sin(time * TAU * 7392.0) * 0.15
			var sample := int(tone * envelope * 6500)
			data.append(sample & 255)
			data.append((sample >> 8) & 255)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		streams[cue] = stream
	for index in range(EnemyAttacks.ORDER.size()):
		var cue: String = "enemy_" + EnemyAttacks.ORDER[index]
		var data := PackedByteArray()
		# Seven original cues: cleaver, string, chitter, fist blade,
		# triple string, heavy axe, rifle mechanism.
		var frequency: float = [720.0, 1350.0, 220.0, 980.0, 1650.0, 340.0, 2400.0][index]
		for i in range(2646):
			var t := float(i) / 22050.0
			var envelope := exp(-t * (38 if index in [1, 4, 6] else 24))
			var tone := sin(TAU * frequency * t + sin(t * 170) * (3.0 if index == 2 else 0.3))
			tone = tone * 0.65 + sin(t * TAU * frequency * 2.71) * 0.25
			if index in [0, 3, 5, 6]: tone += sin(t * TAU * 7919) * sin(t * TAU * 3571) * 0.35
			if index == 4: envelope *= 0.7 + 0.3 * cos(t * TAU * 65)
			var sample := int(clampf(tone * envelope, -1, 1) * 7000)
			data.append(sample & 255)
			data.append((sample >> 8) & 255)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		streams[cue] = stream

func play(cue: String, release: bool = false) -> void:
	counts[cue] = int(counts.get(cue, 0)) + 1
	if DisplayServer.get_name() == "headless": return
	if not streams.has(cue) or get_child_count() >= 16: return
	var voice := AudioStreamPlayer.new()
	voice.stream = streams[cue]
	voice.bus = "SFX"
	voice.volume_db = -9 if release else -13
	if FILE_CUES.has(cue):
		voice.volume_db = FILE_CUES[cue][1]
		voice.pitch_scale = 1.0 + randf_range(-1.0, 1.0) * float(FILE_CUES[cue][2])
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func _exit_tree() -> void:
	for voice in get_children():
		voice.stop()
		voice.stream = null
	streams.clear()
