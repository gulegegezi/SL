extends RefCounted
## 运行时合成打字机 blip 与确认音，不依赖外部音频文件（headless 下只是无声播放）。

static var _blip: AudioStreamWAV
static var _confirm: AudioStreamWAV

static func _tone(freq: float, ms: float, vol: float, square: bool) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * ms / 1000.0)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / rate
		var env := 1.0 - float(i) / n
		var v: float
		if square:
			v = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		else:
			v = sin(t * freq * TAU)
		var s := int(clampf(v * env * vol * 32000.0, -32000.0, 32000.0))
		data.encode_s16(i * 2, s)
	wav.data = data
	return wav

static func blip() -> AudioStreamWAV:
	if _blip == null:
		_blip = _tone(1120.0, 0.028, 0.45, true)
	return _blip

static func confirm() -> AudioStreamWAV:
	if _confirm == null:
		_confirm = _tone(660.0, 0.09, 0.5, false)
	return _confirm
