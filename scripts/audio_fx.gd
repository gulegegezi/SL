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
