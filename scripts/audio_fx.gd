extends RefCounted
## 芯片音效库：运行时合成，不依赖任何外部音频文件（headless 下静音，不报错）。
##
## 音色按「8-bit 家用机 UI」的路子做：方波 / 三角波 / 噪声，极短衰减，
## 幅度做 4-bit 量化，所以听起来颗粒感很强，而不是柔和的正弦。
## 所有音效都是本工程原创合成，没有采样自任何现有游戏。

static var enabled := true
static var volume_db := -6.0
static var _cache: Dictionary = {}
static var _players: Dictionary = {}

const RATE := 22050          # 8-bit 时代的采样率，自带一点毛刺
const POOL := 6              # 同时最多 6 个发声体，够用且不会堆积


# ==========================================================
# 合成
# ==========================================================
static func _square(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0


static func _triangle(phase: float) -> float:
	var p := fmod(phase, 1.0)
	return 4.0 * absf(p - 0.5) - 1.0


## 4-bit 幅度量化：这一层决定「颗粒感」
static func _crunch(v: float, steps: float = 15.0) -> float:
	return roundf(v * steps) / steps


## freqs 是音符序列；glide 让一个音滑向下一个；noise_mix 混一点噪声（纸声、擦伤）
static func _render(freqs: Array, note_ms: float, wave: String, vol: float,
		decay: float = 2.2, glide: bool = false, noise_mix: float = 0.0) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var per := maxi(1, int(RATE * note_ms / 1000.0))
	var total := per * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in range(total):
		var note_index: int = mini(i / per, freqs.size() - 1)
		var local: float = float(i % per) / float(per)
		var f: float = float(freqs[note_index])
		if glide and note_index + 1 < freqs.size():
			f = lerpf(f, float(freqs[note_index + 1]), local)
		phase += f / RATE
		var v: float
		match wave:
			"tri":
				v = _triangle(phase)
			"sin":
				v = sin(phase * TAU)
			"noise":
				v = rng.randf_range(-1.0, 1.0)
			_:
				v = _square(phase)
		if noise_mix > 0.0:
			v = lerpf(v, rng.randf_range(-1.0, 1.0), noise_mix)
		var env: float = pow(1.0 - local, decay)
		v = _crunch(v * env, 15.0) * vol
		data.encode_s16(i * 2, int(clampf(v * 32000.0, -32000.0, 32000.0)))
	wav.data = data
	return wav


## 兼容旧接口：外部按 _tone() 调用的地方继续可用
static func _tone(freq: float, ms: float, vol: float, square: bool) -> AudioStreamWAV:
	return _render([freq], ms, "square" if square else "sin", vol)


# ==========================================================
# 音效表
# ==========================================================
static func stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var wav: AudioStreamWAV
	match name:
		# —— 对白 ——
		"blip":      wav = _render([1180.0], 26.0, "square", 0.42, 3.0)
		"blip_low":  wav = _render([520.0], 30.0, "square", 0.38, 3.0)
		"blip_big":  wav = _render([300.0], 46.0, "square", 0.40, 2.0)
		# —— 菜单 ——
		"move":      wav = _render([1480.0], 16.0, "square", 0.28, 3.5)
		"select":    wav = _render([784.0, 1175.0], 52.0, "square", 0.44, 2.0)
		"cancel":    wav = _render([660.0, 440.0], 60.0, "square", 0.40, 2.0)
		"locked":    wav = _render([240.0, 190.0], 70.0, "square", 0.34, 1.6, false, 0.25)
		# —— 剧情推进 ——
		"page":      wav = _render([900.0], 110.0, "noise", 0.26, 3.2)
		"reveal":    wav = _render([1046.0], 22.0, "square", 0.20, 4.0)
		"discover":  wav = _render([523.0, 659.0, 784.0, 1046.0], 46.0, "tri", 0.40, 1.6)
		"result":    wav = _render([523.0, 659.0, 784.0], 70.0, "square", 0.40, 1.8)
		"save":      wav = _render([523.0, 659.0, 880.0, 1046.0], 58.0, "tri", 0.42, 1.4)
		# —— 状态 ——
		"hurt":      wav = _render([420.0, 180.0], 90.0, "square", 0.44, 1.4, true, 0.30)
		"heal":      wav = _render([620.0, 930.0], 80.0, "tri", 0.40, 1.2, true)
		"coin":      wav = _render([1046.0, 1568.0], 40.0, "square", 0.34, 2.4)
		# —— 章节 ——
		"chapter":   wav = _render([330.0, 440.0, 660.0], 80.0, "square", 0.38, 1.6)
		"ending":    wav = _render([392.0, 523.0, 659.0, 784.0, 1046.0], 110.0, "tri", 0.44, 1.2)
		_:
			wav = _render([880.0], 24.0, "square", 0.32, 3.0)
	_cache[name] = wav
	return wav


# ==========================================================
# 播放：自带小对象池，避免每次 new AudioStreamPlayer
# ==========================================================
static func _pool(host: Node) -> Array:
	if _players.has(host) and is_instance_valid(_players[host][0]):
		return _players[host]
	var players: Array = []
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.name = "__sfx_%d" % i
		host.add_child(p)
		players.append(p)
	_players[host] = players
	return players


static func play(host: Node, name: String, pitch: float = 1.0, db: float = 0.0) -> void:
	if not enabled or host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var players := _pool(host)
	for p in players:
		if not p.playing:
			p.stream = stream(name)
			p.pitch_scale = clampf(pitch, 0.5, 2.0)
			p.volume_db = volume_db + db
			p.play()
			return
	# 全忙就复用第一个：宁可掐掉旧声，也不堆积延迟
	var first: AudioStreamPlayer = players[0]
	first.stream = stream(name)
	first.pitch_scale = clampf(pitch, 0.5, 2.0)
	first.volume_db = volume_db + db
	first.play()


## 对白逐字：音高抖一点，听起来像不同角色在说话
static func speak(host: Node, low: bool = false, pitch: float = -1.0) -> void:
	var p := pitch
	if p < 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = Time.get_ticks_usec()
		p = rng.randf_range(0.94, 1.06)
	play(host, "blip_low" if low else "blip", p)


# ==========================================================
# 背景音乐：同样是运行时合成，一条循环轨
# 结构：4 段和弦 × 2 小节，8 分音符琶音 + 低音 + 轻噪声打点
# ==========================================================
const MUSIC_RATE := 22050
static var _music_cache: Dictionary = {}
static var _music_player: AudioStreamPlayer

## 轨道定义：bpm、根音(MIDI)、四段和弦（相对根音的半音）、琶音密度
const TRACKS := {
	"title": {
		"bpm": 82.0, "root": 57,
		"chords": [[0, 3, 7, 10], [5, 8, 12, 15], [-2, 2, 5, 9], [3, 7, 10, 14]],
		"lead": "square", "lead_vol": 0.16, "bass_vol": 0.20, "hat": 0.05
	},
	"story": {
		"bpm": 72.0, "root": 60,
		"chords": [[0, 4, 7, 11], [-3, 2, 5, 9], [5, 9, 12, 16], [-1, 3, 7, 10]],
		"lead": "tri", "lead_vol": 0.13, "bass_vol": 0.18, "hat": 0.03
	},
	"ending": {
		"bpm": 58.0, "root": 53,
		"chords": [[0, 4, 7, 12], [-4, 0, 3, 7], [5, 9, 12, 17], [0, 3, 7, 10]],
		"lead": "tri", "lead_vol": 0.15, "bass_vol": 0.17, "hat": 0.0
	},
}


static func _midi_hz(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


static func music(track: String) -> AudioStreamWAV:
	if _music_cache.has(track):
		return _music_cache[track]
	var spec: Dictionary = TRACKS.get(track, TRACKS["title"])
	var bpm: float = float(spec["bpm"])
	var beat: float = 60.0 / bpm
	var step: float = beat * 0.5               # 8 分音符
	var root: int = int(spec["root"])
	var chords: Array = spec["chords"]
	var bars := chords.size() * 2              # 每个和弦两小节
	var steps_per_bar := 8
	var total_steps := bars * steps_per_bar
	var step_samples := int(MUSIC_RATE * step)
	var total := total_steps * step_samples
	var data := PackedByteArray()
	data.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lead_wave: String = str(spec["lead"])
	for i in range(total):
		var step_index: int = i / step_samples
		var local: float = float(i % step_samples) / float(step_samples)
		var chord_index: int = (step_index / (steps_per_bar * 2)) % chords.size()
		var chord: Array = chords[chord_index]
		var in_bar: int = step_index % (steps_per_bar * 2)
		var v := 0.0
		# 琶音：按和弦音循环，每两步换一个音
		var tone: int = root + int(chord[(in_bar / 2) % chord.size()])
		var lead_phase := fmod(float(i) * _midi_hz(tone) / MUSIC_RATE, 1.0)
		var lead := _triangle(lead_phase) if lead_wave == "tri" else _square(lead_phase)
		# 每个 8 分音符重新起包络，听起来有颗粒
		v += lead * pow(1.0 - local, 2.4) * float(spec["lead_vol"])
		# 低音：每小节第一拍和第三拍
		if in_bar % 4 == 0:
			var bass_note: int = root - 12 + int(chord[0])
			var bass_phase := fmod(float(i) * _midi_hz(bass_note) / MUSIC_RATE, 1.0)
			v += _triangle(bass_phase) * 0.55 * float(spec["bass_vol"])
		# 打点：轻噪声，落在偶数步上
		if float(spec["hat"]) > 0.0 and step_index % 2 == 0:
			v += rng.randf_range(-1.0, 1.0) * float(spec["hat"]) * pow(1.0 - local, 8.0)
		v = _crunch(v, 15.0)
		data.encode_s16(i * 2, int(clampf(v * 30000.0, -30000.0, 30000.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUSIC_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	_music_cache[track] = wav
	return wav


## 播放（循环）。同一 track 重复调用不会重开
static func play_music(host: Node, track: String = "title", db: float = -14.0) -> void:
	if not enabled or host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	if _music_player == null or not is_instance_valid(_music_player):
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "__bgm"
		host.add_child(_music_player)
	if _music_player.playing and _music_player.stream == music(track):
		return
	_music_player.stream = music(track)
	_music_player.volume_db = db
	_music_player.play()


static func stop_music() -> void:
	if _music_player != null and is_instance_valid(_music_player):
		_music_player.stop()
