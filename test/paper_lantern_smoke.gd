extends SceneTree
const AudioFX := preload("res://scripts/audio_fx.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var music := AudioFX.music("story")
	check(music.stereo and music.mix_rate == 32000, "stereo 32 kHz import")
	check(music.format == AudioStreamWAV.FORMAT_16_BITS, "lossless PCM import")
	check(absf(music.get_length() - 96.0) < .001, "exact 32-bar duration")
	check(music.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.loop_end == 3072000, "full-length loop")
	check(music.data.size() == music.loop_end * 4, "loop ends at final stereo frame")
	check(AudioFX.music("title") == music, "menu and reader share the same recording")
	var playback := music.instantiate_playback()
	playback.start(95.98)
	var crossing := playback.mix_audio(1.0, 3200)
	print("loop probe: samples=", crossing.size(), " position=", playback.get_playback_position(), " loops=", playback.get_loop_count())
	check(crossing.size() == 3200 and playback.get_playback_position() < 1.0 and playback.is_playing(), "decoder crosses loop without stopping")
	playback.stop()
	playback = null
	var old_scene := Node.new()
	root.add_child(old_scene)
	AudioFX.play_music(old_scene, "title")
	var player := AudioFX._music_player
	await create_timer(.1).timeout
	old_scene.queue_free()
	await process_frame
	check(is_instance_valid(player) and player.get_parent() == root, "BGM survives old scene removal")
	var next_scene := Node.new()
	root.add_child(next_scene)
	var cursor := player.get_playback_position()
	AudioFX.play_music(next_scene, "story")
	check(player == AudioFX._music_player and player.get_playback_position() >= cursor, "entering reader does not restart music")
	AudioFX.set_music_enabled(false)
	check(player.stream_paused, "music-only pause")
	AudioFX.set_music_enabled(true)
	check(not player.stream_paused, "music resumes")
	AudioFX.stop_music()
	player.queue_free()
	next_scene.queue_free()
	# Let the audio mixer retire its playback reference before process shutdown.
	await create_timer(.15).timeout
	print("PAPER_LANTERN_SMOKE ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
