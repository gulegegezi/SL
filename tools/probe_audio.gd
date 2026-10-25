extends SceneTree
## 音效探针：把音频库里的每个音效导出成 WAV，并打印时长/峰值，便于试听与验收。
## 用法：godot --headless --path . --script res://tools/probe_audio.gd -- <输出目录>

const AudioFX := preload("res://scripts/audio_fx.gd")

const NAMES := ["blip", "blip_low", "blip_big", "move", "select", "cancel", "locked",
	"page", "reveal", "discover", "result", "save", "hurt", "heal", "coin",
	"chapter", "ending"]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := "user://sfx_preview"
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var rows: Array = []
	for name in NAMES:
		var wav: AudioStreamWAV = AudioFX.stream(name)
		var bytes := wav.data
		var samples := bytes.size() / 2
		var ms := float(samples) / float(wav.mix_rate) * 1000.0
		var peak := 0
		var sum := 0.0
		for i in range(samples):
			var v: int = bytes.decode_s16(i * 2)
			peak = maxi(peak, absi(v))
			sum += float(v) * float(v)
		var rms: float = sqrt(sum / maxf(1.0, float(samples)))
		var path := out_dir.path_join(name + ".wav")
		wav.save_to_wav(path)
		rows.append({"name": name, "ms": ms, "peak": peak / 32768.0, "rms": rms / 32768.0, "path": path})
		print("  %-10s %6.1f ms  峰值 %.2f  RMS %.3f" % [name, ms, peak / 32768.0, rms / 32768.0])
	print("导出了 ", rows.size(), " 个音效 -> ", out_dir)
	quit()
