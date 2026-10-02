extends SceneTree
## Bounded audio resources under repeated retries, pickups, and long Endless runs.
## This uses an isolated APPDATA profile through tools/Check-Project.ps1.
var checks := 0
var failures := 0
var ui

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(390, 716)
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.set_process(false)
	ui.muted = false
	check(ui.players.size() == 4, "audio player pool remains fixed")
	for player in ui.players:
		check(player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "sounds bypass web Sample backend")
	ui.tone(440.0, 0.10)
	var original: AudioStreamWAV = ui.players[0].stream
	check(original.mix_rate == 22050 and original.data.size() == 4410, "cached tone retains original duration and sample rate")
	for replay in range(100):
		ui.tone(440.0, 0.10)
	check(ui.tone_streams.size() == 1, "repeated sounds reuse one waveform")
	for player in ui.players:
		check(player.stream == original, "all players share cached waveform")

	# Exercise real event routing without changing a best or writing any save.
	ui.game.start("endless", 0)
	for bite in range(1, 15):
		ui.game.eaten = bite
		ui.handle_event("food")
	var warm_size: int = ui.tone_streams.size()
	var high_tone: AudioStreamWAV = ui.players[(ui.player_index + 3) % 4].stream
	var warm_ids: Dictionary = {}
	for key in ui.tone_streams:
		warm_ids[key] = ui.tone_streams[key].get_instance_id()
	for bite in range(15, 1015):
		ui.game.eaten = bite
		ui.handle_event("food")
	check(ui.tone_streams.size() == warm_size, "one thousand Endless bites do not grow the sound cache")
	for key in warm_ids:
		check(ui.tone_streams[key].get_instance_id() == warm_ids[key], "long run reuses existing waveforms")
	check(ui.players[(ui.player_index + 3) % 4].stream == high_tone, "Endless pitch stops at final Campaign pitch")

	var quiet_size: int = ui.tone_streams.size()
	var quiet_index: int = ui.player_index
	ui.muted = true
	ui.tone(1234.0, 0.1)
	check(ui.tone_streams.size() == quiet_size and ui.player_index == quiet_index, "muted sounds allocate and play nothing")
	ui.muted = false
	for pitch in range(80):
		ui.tone(200.0 + pitch, 0.01)
	check(ui.tone_streams.size() <= ui.TONE_CACHE_LIMIT, "future arbitrary pitches cannot grow cache without bound")
	check(ui.players.size() == 4, "stress run does not allocate more players")
	for player in ui.players:
		check(is_instance_valid(player.stream), "cache eviction preserves active player stream")
		player.stop()
	# Let the mixer drain stopped playbacks from this deliberately rapid burst.
	await create_timer(0.5).timeout
	ui.free()
	await process_frame
	print("STABILITY CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
