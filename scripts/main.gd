extends Control

const Rules = preload("res://scripts/snake_game.gd")
const BG := Color("101b24")
const PANEL := Color("172730")
const LINE := Color("2b4049")
const INK := Color("edf3df")
const MUTED := Color("92a7ab")
const GREEN := Color("c3ef72")
const GOLD := Color("ffc96b")
const BLUE := Color("7cd9dd")
const LILAC := Color("c5a5ed")
const MEDAL_COLORS := [Color("d6a177"), Color("c4d2dc"), GOLD]
const MEDAL_NAMES := ["Bronze", "Silver", "Gold"]
const BOARD := Vector2(48, 214)
const CELL := 26.0
var game = Rules.new()
var regular: Font
var bold: Font
var phone = preload("res://scripts/phone_ui.gd").new(self)
var phone_layout := false
var phone_ready := false
var web_pause_callback: JavaScriptObject
var elapsed := 0.0
var clock_time := 0.0
var best := 0
var cleared_count := 0
var endless_bests: Array[int] = []
var adventure_bests: Array[int] = []
var adventure_times: Array[float] = []
var adventure_tab: Button
var replay_button: Button
var menu_mode := "campaign"
var selected_stage := 0
var menu_preview = Rules.new()
var legacy_restore_pending := false
var restore_open := false
var restore_selection := 0
var muted := false
var pickup_feedback: Dictionary = {}
var action_button: Button
var pause_button: Button
var mute_button: Button
var menu_button: Button
var restart_button: Button
var campaign_tab: Button
var endless_tab: Button
var arena_buttons: Array[Button] = []
var restore_button: Button
var restore_minus: Button
var restore_plus: Button
var restore_confirm: Button
var restore_cancel: Button
var players: Array[AudioStreamPlayer] = []
var player_index := 0
var last_state := ""

func _ready() -> void:
	if OS.has_feature("web"):
		regular = ThemeDB.fallback_font
		bold = ThemeDB.fallback_font
	else:
		var normal := SystemFont.new()
		normal.font_names = PackedStringArray(["Segoe UI", "Arial"])
		var heavy := SystemFont.new()
		heavy.font_names = normal.font_names
		heavy.font_weight = 700
		regular = normal
		bold = heavy
	endless_bests.resize(Rules.STAGES.size())
	endless_bests.fill(0)
	adventure_bests.resize(Rules.ADVENTURES.size())
	adventure_bests.fill(0)
	adventure_times.resize(Rules.ADVENTURES.size())
	adventure_times.fill(0.0)
	var saved := ConfigFile.new()
	if saved.load("user://progress.cfg") == OK:
		best = maxi(0, int(saved.get_value("game", "best", 0)))
		muted = bool(saved.get_value("game", "muted", false))
		cleared_count = clampi(int(saved.get_value("campaign", "cleared_count", 0)), 0, Rules.STAGES.size())
		legacy_restore_pending = bool(saved.get_value("campaign", "legacy_restore_pending", best > 0 and not saved.has_section_key("campaign", "cleared_count")))
		for i in range(endless_bests.size()):
			endless_bests[i] = maxi(0, int(saved.get_value("endless", "stage_%02d" % (i + 1), 0)))
		for i in range(adventure_bests.size()):
			adventure_bests[i] = maxi(0, int(saved.get_value("adventure", "level_%02d" % (i + 1), 0)))
			adventure_times[i] = maxf(0.0, float(saved.get_value("adventure", "time_%02d" % (i + 1), 0.0)))
	pause_button = make_button("Pause", Rect2(850, 53, 96, 40), toggle_pause, false)
	mute_button = make_button("Sound on", Rect2(958, 53, 102, 40), toggle_sound, false)
	menu_button = make_button("Menu", Rect2(742, 53, 96, 40), show_menu, false)
	action_button = make_button("Start run   →", Rect2(190, 509, 340, 48), primary_action, true)
	restart_button = make_button("New run", Rect2(916, 765, 144, 34), new_run, false)
	campaign_tab = make_button("Campaign", Rect2(48, 163, 145, 40), select_mode.bind("campaign"), false)
	endless_tab = make_button("Endless", Rect2(205, 163, 145, 40), select_mode.bind("endless"), false)
	adventure_tab = make_button("Adventure", Rect2(362, 163, 145, 40), select_mode.bind("adventure"), false)
	replay_button = make_button("Replay maze", Rect2(260, 565, 200, 34), new_run, false)
	for i in range(Rules.STAGES.size()):
		var button := make_button("", arena_bounds(i), select_arena.bind(i), false)
		button.add_theme_stylebox_override("normal", box(Color.TRANSPARENT, 10))
		button.add_theme_stylebox_override("disabled", box(Color.TRANSPARENT, 10))
		button.add_theme_stylebox_override("hover", box(Color(1, 1, 1, 0.035), 10, GREEN))
		button.add_theme_stylebox_override("pressed", box(Color(1, 1, 1, 0.06), 10, GREEN))
		arena_buttons.append(button)
	restore_button = make_button("Restore earlier progress", Rect2(743, 610, 294, 40), open_restore, false)
	restore_minus = make_button("−", Rect2(370, 425, 64, 42), change_restore.bind(-1), false)
	restore_plus = make_button("+", Rect2(666, 425, 64, 42), change_restore.bind(1), false)
	restore_confirm = make_button("Restore cleared stages", Rect2(380, 510, 340, 48), confirm_restore, true)
	restore_cancel = make_button("Back", Rect2(490, 577, 120, 36), cancel_restore, false)
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -16.0
		add_child(player)
		players.append(player)
	get_viewport().size_changed.connect(update_layout)
	update_layout()
	if OS.has_feature("web"):
		web_pause_callback = JavaScriptBridge.create_callback(web_backgrounded)
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", web_pause_callback)
		JavaScriptBridge.get_interface("window").addEventListener("pagehide", web_pause_callback)
	sync_buttons()
	queue_redraw()

func make_button(label: String, bounds: Rect2, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.set_meta("desktop_bounds", bounds)
	button.set_meta("desktop_font_size", 16 if primary else 14)
	button.text = label
	button.position = bounds.position
	button.size = bounds.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", bold)
	button.add_theme_font_size_override("font_size", 16 if primary else 14)
	button.add_theme_color_override("font_color", BG if primary else INK)
	button.add_theme_color_override("font_hover_color", BG if primary else GREEN)
	button.add_theme_color_override("font_pressed_color", BG if primary else GREEN)
	button.add_theme_stylebox_override("normal", box(GREEN if primary else PANEL, 8, GREEN if primary else LINE))
	button.add_theme_stylebox_override("hover", box(Color("d8ffa0") if primary else Color("223841"), 8, GREEN))
	button.add_theme_stylebox_override("pressed", box(Color("a7ce5d") if primary else BG, 8, GREEN))
	button.pressed.connect(callback)
	add_child(button)
	return button

func box(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	return style

func panel(bounds: Rect2, color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> void:
	draw_style_box(box(color, radius, border), bounds)

func words(value: String, pos: Vector2, font_size: int = 16, color: Color = INK, heavy: bool = false) -> void:
	draw_string(bold if heavy else regular, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func centered(value: String, y: float, font_size: int, color: Color = INK, heavy: bool = false) -> void:
	var font := bold if heavy else regular
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	words(value, Vector2(360 - width / 2, y), font_size, color, heavy)

func _process(delta: float) -> void:
	clock_time += delta
	for kind in pickup_feedback.keys():
		pickup_feedback[kind].remaining = maxf(0.0, pickup_feedback[kind].remaining - delta)
		if pickup_feedback[kind].remaining <= 0.0:
			pickup_feedback.erase(kind)
	if game.state == "playing":
		var active_delta: float = delta if elapsed >= 0.0 else maxf(0.0, elapsed + delta)
		game.tick_effects(active_delta if game.mode == "adventure" else delta)
		elapsed += delta
		if elapsed >= game.interval():
			# Never fast-forward multiple grid moves after a stalled frame.
			elapsed = fmod(elapsed, game.interval())
			handle_event(game.step())
	if game.state != last_state:
		sync_buttons()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		pause_for_background()

func pause_for_background() -> void:
	phone.swipe_origins.clear()
	if game.state == "playing":
		game.state = "paused"
		elapsed = 0.0
		sync_buttons()

func web_backgrounded(_arguments: Array) -> void:
	pause_for_background()

func _input(event: InputEvent) -> void:
	if phone_layout:
		phone.handle_input(event)

func steer(turn: Vector2i) -> void:
	if game.state == "shield_save":
		if game.resume_from_shield(turn):
			elapsed = 0.0
	else:
		game.queue_turn(turn)

func update_layout() -> void:
	var available := get_viewport_rect().size
	if available.x <= 0 or available.y <= 0:
		return
	var previous := phone_layout
	phone_layout = "--phone-preview" in OS.get_cmdline_user_args() or available.x < 760 or (available.y < 600 and (OS.has_feature("web") or DisplayServer.is_touchscreen_available()))
	if OS.has_feature("web"):
		phone_layout = bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches || document.getElementById('canvas').clientWidth < 760 || document.getElementById('canvas').clientHeight < 600"))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	if phone_layout:
		var factor := available.y / 390.0 if available.x > available.y else available.x / 390.0
		scale = Vector2.ONE * factor
		position = Vector2.ZERO
		size = available / factor
		phone.configure(size)
	else:
		var factor := minf(available.x / 1100.0, available.y / 820.0)
		scale = Vector2.ONE * factor
		position = (available - Vector2(1100, 820) * factor) / 2.0
		size = Vector2(1100, 820)
	if previous != phone_layout or game.state == "playing":
		pause_for_background()
	sync_buttons()
	queue_redraw()

func prepare_phone_start() -> void:
	phone_ready = phone_layout
	if phone_ready:
		game.state = "paused"
	phone.swipe_origins.clear()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if restore_open:
		match event.physical_keycode:
			KEY_LEFT, KEY_DOWN: change_restore(-1)
			KEY_RIGHT, KEY_UP: change_restore(1)
			KEY_ENTER, KEY_KP_ENTER: confirm_restore()
			KEY_ESCAPE: cancel_restore()
		get_viewport().set_input_as_handled()
		return
	var turn := Vector2i.ZERO
	match event.physical_keycode:
		KEY_UP, KEY_W: turn = Vector2i.UP
		KEY_DOWN, KEY_S: turn = Vector2i.DOWN
		KEY_LEFT, KEY_A: turn = Vector2i.LEFT
		KEY_RIGHT, KEY_D: turn = Vector2i.RIGHT
		KEY_ENTER, KEY_KP_ENTER:
			primary_action()
		KEY_SPACE, KEY_ESCAPE:
			if game.state == "title":
				primary_action()
			else:
				toggle_pause()
		KEY_R: new_run()
		KEY_M: toggle_sound()
	if turn != Vector2i.ZERO:
		if game.state == "title" and menu_mode in ["endless", "adventure"]:
			select_arena(clampi(selected_stage + turn.x + turn.y * 2, 0, (Rules.ADVENTURES.size() - 1) if menu_mode == "adventure" else maxi(0, cleared_count - 1)))
		else:
			steer(turn)
	get_viewport().set_input_as_handled()

func new_run() -> void:
	var run_mode: String = menu_mode if game.state == "title" else game.mode
	var arena: int = selected_stage if game.state == "title" else game.stage
	if run_mode == "endless" and arena >= cleared_count:
		return
	game.start(run_mode, arena)
	prepare_phone_start()
	elapsed = -0.6
	pickup_feedback.clear()
	tone(440.0, 0.10)
	sync_buttons()

func arena_bounds(index: int) -> Rect2:
	return Rect2(48 + (index % 2) * 320, 254 + floori(index / 2.0) * 94, 304, 80)

func select_mode(value: String) -> void:
	menu_mode = value
	select_arena(selected_stage)
	sync_buttons()

func select_arena(index: int) -> void:
	selected_stage = clampi(index, 0, (Rules.ADVENTURES.size() if menu_mode == "adventure" else Rules.STAGES.size()) - 1)
	menu_preview.mode = menu_mode
	menu_preview.stage = selected_stage
	menu_preview.prepare_stage()
	sync_buttons()
	queue_redraw()

func show_menu() -> void:
	phone_ready = false
	phone.swipe_origins.clear()
	menu_mode = game.mode
	if game.mode in ["endless", "adventure"]:
		selected_stage = game.stage
	game.state = "title"
	pickup_feedback.clear()
	select_arena(selected_stage)

func current_best() -> int:
	if game.mode == "adventure":
		return adventure_bests[game.stage]
	return endless_bests[game.stage] if game.mode == "endless" else best

func open_restore() -> void:
	if not legacy_restore_pending:
		return
	restore_open = true
	restore_selection = cleared_count
	sync_buttons()

func change_restore(amount: int) -> void:
	restore_selection = clampi(restore_selection + amount, cleared_count, Rules.STAGES.size())
	sync_buttons()

func cancel_restore() -> void:
	restore_open = false
	sync_buttons()

func confirm_restore() -> void:
	if not restore_open or not legacy_restore_pending:
		return
	cleared_count = maxi(cleared_count, restore_selection)
	legacy_restore_pending = false
	restore_open = false
	save_progress()
	menu_mode = "endless"
	select_arena(maxi(0, cleared_count - 1))

func primary_action() -> void:
	if phone_ready:
		phone_ready = false
		game.state = "playing"
		elapsed = -0.35
		sync_buttons()
		return
	var previous: String = game.state
	match game.state:
		"title", "game_over", "victory": new_run()
		"adventure_clear":
			if game.stage < Rules.ADVENTURES.size() - 1:
				game.start("adventure", game.stage + 1)
				elapsed = -0.7
				pickup_feedback.clear()
			else:
				show_menu()
		"paused": toggle_pause()
		"stage_clear":
			game.next_stage()
			pickup_feedback.clear()
			elapsed = -0.7
			tone(660.0, 0.15)
	if previous in ["stage_clear", "adventure_clear"] and game.state == "playing":
		prepare_phone_start()
	sync_buttons()

func toggle_pause() -> void:
	if phone_ready:
		primary_action()
		return
	phone.swipe_origins.clear()
	if game.state == "playing":
		game.state = "paused"
	elif game.state == "paused":
		game.state = "playing"
		elapsed = -0.3
	sync_buttons()

func toggle_sound() -> void:
	muted = not muted
	save_progress()
	sync_buttons()

func save_progress() -> void:
	var saved := ConfigFile.new()
	saved.set_value("game", "best", best)
	saved.set_value("game", "muted", muted)
	saved.set_value("campaign", "cleared_count", cleared_count)
	saved.set_value("campaign", "legacy_restore_pending", legacy_restore_pending)
	for i in range(endless_bests.size()):
		saved.set_value("endless", "stage_%02d" % (i + 1), endless_bests[i])
	for i in range(adventure_bests.size()):
		saved.set_value("adventure", "level_%02d" % (i + 1), adventure_bests[i])
		saved.set_value("adventure", "time_%02d" % (i + 1), adventure_times[i])
	var error := saved.save("user://progress.cfg")
	if error != OK:
		push_warning("Could not save the high score: " + str(error))

func handle_event(event: String) -> void:
	var changed := false
	if game.mode == "adventure":
		if event == "adventure_clear":
			if game.score > adventure_bests[game.stage]:
				adventure_bests[game.stage] = game.score
				changed = true
			if adventure_times[game.stage] == 0.0 or game.run_time < adventure_times[game.stage]:
				adventure_times[game.stage] = game.run_time
				changed = true
	elif game.mode == "endless":
		if game.score > endless_bests[game.stage]:
			endless_bests[game.stage] = game.score
			changed = true
	elif game.score > best:
		best = game.score
		changed = true
	if game.mode == "campaign" and event in ["stage_clear", "victory"]:
		if cleared_count < game.stage + 1:
			cleared_count = game.stage + 1
			changed = true
	if changed:
		save_progress()
	match event:
		"food": tone(620.0 + game.eaten * 45.0, 0.07)
		"shield":
			confirm_pickup("shield", "Shield used" if game.state == "shield_save" else "Shield ready")
			tone(350.0, 0.20)
		"shed":
			var count: int = game.last_shed_count
			confirm_pickup("shed", "Minimum length reached" if count == 0 else "−%d segment%s" % [count, "" if count == 1 else "s"])
			tone(740.0, 0.14)
		"bonus":
			confirm_pickup("bonus", "+50 points")
			tone(960.0, 0.18)
		"board_full":
			confirm_pickup("shed", "Perfect board! Tail trimmed.")
			tone(880.0, 0.25)
		"crash": tone(125.0, 0.35)
		"stage_clear", "victory", "adventure_clear": tone(880.0, 0.35)

func confirm_pickup(kind: String, text: String) -> void:
	# Feedback stays in its existing sidebar card; the playfield stays unobscured.
	pickup_feedback[kind] = {"text": text, "remaining": 1.6}

func tone(frequency: float, duration: float) -> void:
	if muted or players.is_empty():
		return
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / sample_rate
		var envelope := minf(t * 80.0, 1.0) * pow(1.0 - float(i) / count, 2.0)
		var sample := int(sin(TAU * frequency * t) * envelope * 24000)
		bytes.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	players[player_index].stream = stream
	players[player_index].play()
	player_index = (player_index + 1) % players.size()

func sync_buttons() -> void:
	if not is_instance_valid(action_button):
		return
	for child in get_children():
		if child is Button and child.has_meta("desktop_bounds"):
			var bounds: Rect2 = child.get_meta("desktop_bounds")
			child.position = bounds.position
			child.size = bounds.size
			child.add_theme_font_size_override("font_size", child.get_meta("desktop_font_size"))
	restart_button.text = "New run"
	last_state = game.state
	action_button.visible = game.state in ["title", "paused", "stage_clear", "game_over", "victory", "adventure_clear"]
	var labels := {"title": "Start run   →", "paused": "Resume   →", "stage_clear": "Next stage   →", "game_over": "Try again   →", "victory": "Play again   →"}
	action_button.text = labels.get(game.state, "Start run   →")
	if phone_ready:
		action_button.text = "Go!   →"
	if game.state == "adventure_clear":
		action_button.text = "Next maze   →" if game.stage < Rules.ADVENTURES.size() - 1 else "Choose a maze   →"
	replay_button.visible = game.state == "adventure_clear"
	var on_menu: bool = game.state == "title"
	action_button.position = Vector2(720, 694) if on_menu else Vector2(190, 509)
	action_button.disabled = on_menu and menu_mode == "endless" and selected_stage >= cleared_count
	if on_menu:
		action_button.text = "Start campaign   →" if menu_mode == "campaign" else ("Play Endless   →" if selected_stage < cleared_count else "Clear this stage to unlock")
	if on_menu and menu_mode == "adventure":
		action_button.text = "Enter maze   →"
	adventure_tab.visible = on_menu
	campaign_tab.visible = on_menu
	endless_tab.visible = on_menu
	for tab in [campaign_tab, endless_tab, adventure_tab]:
		var selected: bool = tab == {"campaign": campaign_tab, "endless": endless_tab, "adventure": adventure_tab}[menu_mode]
		tab.add_theme_stylebox_override("normal", box(PANEL, 8, GREEN if selected else LINE))
		tab.add_theme_color_override("font_color", GREEN if selected else INK)
	for i in range(arena_buttons.size()):
		arena_buttons[i].visible = on_menu and (menu_mode == "endless" or (menu_mode == "adventure" and i < Rules.ADVENTURES.size()))
		arena_buttons[i].disabled = menu_mode == "endless" and i >= cleared_count
	menu_button.visible = not on_menu
	restart_button.visible = not on_menu
	pause_button.visible = not on_menu
	restore_button.visible = on_menu and menu_mode == "campaign" and legacy_restore_pending and not restore_open
	for button in [restore_minus, restore_plus, restore_confirm, restore_cancel]:
		button.visible = restore_open
	restore_minus.disabled = restore_selection <= cleared_count
	restore_plus.disabled = restore_selection >= Rules.STAGES.size()
	restore_confirm.text = "Restore %d cleared stages" % restore_selection
	if restore_open:
		campaign_tab.hide()
		endless_tab.hide()
		adventure_tab.hide()
		action_button.hide()
		for button in arena_buttons:
			button.hide()
	pause_button.text = "Resume" if game.state == "paused" else "Pause"
	pause_button.disabled = game.state not in ["playing", "paused"]
	mute_button.text = "Sound off" if muted else "Sound on"
	if OS.has_feature("web"):
		for child in get_children():
			if child is Button:
				child.text = child.text.replace("→", "").replace("−", "-").strip_edges()
	if phone_layout:
		phone.arrange()

func _draw() -> void:
	if phone_layout:
		phone.draw()
		return
	draw_rect(Rect2(0, 0, 1100, 820), BG)
	words("A LITTLE ARCADE ADVENTURE", Vector2(48, 35), 11, GREEN, true)
	words("snake", Vector2(46, 91), 55, INK, true)
	panel(Rect2(211, 60, 98, 32), PANEL, 7, LINE)
	words("S T A G E S", Vector2(225, 82), 14, GREEN, true)
	words("Small bites. Bigger challenges.", Vector2(49, 120), 16, MUTED)
	draw_line(Vector2(48, 143), Vector2(1060, 143), LINE)
	if game.state == "title":
		if restore_open:
			draw_restore()
		else:
			draw_menu()
		return
	words("SCORE", Vector2(48, 174), 11, MUTED, true)
	words("%04d" % game.score, Vector2(112, 180), 29, INK, true)
	words("PERSONAL BEST", Vector2(248, 174), 11, MUTED, true)
	words("%04d" % current_best(), Vector2(357, 180), 23, GOLD, true)
	panel(Rect2(538, 156, 134, 31), PANEL, 15, LINE)
	draw_circle(Vector2(554, 171), 4, GREEN)
	var stage_label: String = "ENDLESS · %02d" % (game.stage + 1) if game.mode == "endless" else "STAGE %02d / %02d" % [game.stage + 1, Rules.STAGES.size()]
	if game.mode == "adventure":
		stage_label = "MAZE %02d / 07" % (game.stage + 1)
	words(stage_label, Vector2(567, 176), 11, INK, true)
	draw_board()
	draw_sidebar()
	words("MOVE  ↑ ↓ ← →  /  WASD", Vector2(48, 779), 13, INK, true)
	words("SPACE  pause     R  restart     M  sound", Vector2(325, 779), 13, MUTED)
	if game.state != "playing":
		draw_overlay()

func medal_badge(center: Vector2, rank: int, earned: bool, radius: float = 11.0) -> void:
	var color: Color = MEDAL_COLORS[rank]
	draw_line(center + Vector2(-4, radius - 2), center + Vector2(-6, radius + 5), color if earned else LINE, 4.0)
	draw_line(center + Vector2(4, radius - 2), center + Vector2(6, radius + 5), color if earned else LINE, 4.0)
	draw_circle(center, radius, color if earned else BG)
	draw_arc(center, radius, 0, TAU, 24, color if earned else LINE, 1.0, true)
	var letter: String = ["B", "S", "G"][rank]
	var width := bold.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	words(letter, center + Vector2(-width / 2, 4), 10, BG if earned else MUTED, true)

func draw_menu() -> void:
	if menu_mode == "adventure":
		draw_adventure_menu()
		return
	var endless := menu_mode == "endless"
	words("Choose a cleared stage. Chase a new personal best." if endless else "Clear the campaign to unlock every Endless arena.", Vector2(48, 237), 15, MUTED)
	words("%d / %d STAGES CLEARED" % [cleared_count, Rules.STAGES.size()], Vector2(720, 190), 12, GREEN, true)
	for i in range(Rules.STAGES.size()):
		var bounds := arena_bounds(i)
		var unlocked := i < cleared_count
		var selected := endless and i == selected_stage
		panel(bounds, Color("20313a") if selected else PANEL, 10, GREEN if selected else LINE)
		words("%02d" % (i + 1), bounds.position + Vector2(15, 27), 12, GREEN if unlocked else MUTED, true)
		words(Rules.STAGES[i].name, bounds.position + Vector2(46, 27), 17, INK if unlocked or not endless else MUTED, true)
		if endless and unlocked:
			words("BEST  %d" % endless_bests[i], bounds.position + Vector2(16, 57), 12, MUTED)
			var rank: int = Rules.medal_rank(i, endless_bests[i])
			for medal in range(3):
				medal_badge(bounds.position + Vector2(218 + medal * 30, 52), medal, medal < rank, 9)
		else:
			var label := "Cleared · Endless unlocked" if unlocked else ("Clear in Campaign to unlock" if endless else ("Next to clear" if i == cleared_count else "Not cleared"))
			words(label, bounds.position + Vector2(16, 57), 12, GREEN if unlocked else MUTED)
	words("Arrow keys select · Enter starts" if endless and cleared_count > 0 else "Enter starts a fresh campaign from stage 1.", Vector2(48, 765), 13, MUTED)
	if endless:
		draw_arena_preview()
	else:
		panel(Rect2(720, 226, 340, 448), PANEL, 14, LINE)
		words("THE MAIN EVENT", Vector2(743, 260), 11, GREEN, true)
		words("Ten stages.", Vector2(743, 303), 30, INK, true)
		words("One great run.", Vector2(743, 339), 30, INK, true)
		words("Grow your score as the paths get tighter", Vector2(743, 385), 14, MUTED)
		words("and the pace picks up.", Vector2(743, 408), 14, MUTED)
		words("Every cleared stage unlocks a new", Vector2(743, 458), 14, INK)
		words("Endless arena permanently.", Vector2(743, 481), 14, INK)
		draw_line(Vector2(743, 519), Vector2(1037, 519), LINE)
		words("CAMPAIGN BEST", Vector2(743, 554), 11, MUTED, true)
		words(str(best), Vector2(743, 594), 32, GOLD, true)
		if not legacy_restore_pending:
			words("Shield. Shed. Keep moving.", Vector2(743, 642), 14, GREEN)

func draw_restore() -> void:
	panel(Rect2(250, 231, 600, 419), PANEL, 16, LINE)
	words("WELCOME BACK", Vector2(292, 275), 11, GREEN, true)
	words("Keep your earlier clears.", Vector2(292, 318), 29, INK, true)
	words("The earlier version saved scores, but not cleared stages.", Vector2(292, 357), 15, MUTED)
	words("Choose the highest stage you already beat in Campaign.", Vector2(292, 383), 15, INK)
	var number := str(restore_selection)
	var width := bold.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	words(number, Vector2(550 - width / 2, 459), 36, GREEN, true)
	words("Arrow keys adjust · Enter confirms", Vector2(428, 491), 12, MUTED)

func draw_arena_preview() -> void:
	var unlocked := selected_stage < cleared_count
	panel(Rect2(720, 226, 340, 448), PANEL, 14, LINE)
	words("ENDLESS ARENA %02d" % (selected_stage + 1), Vector2(743, 256), 11, GREEN if unlocked else MUTED, true)
	words(Rules.STAGES[selected_stage].name, Vector2(743, 287), 25, INK, true)
	var origin := Vector2(758, 309)
	panel(Rect2(origin - Vector2(5, 5), Vector2(274, 230)), BG, 8, LINE)
	for wall in menu_preview.walls:
		draw_rect(Rect2(origin + Vector2(wall) * 11 + Vector2.ONE, Vector2(9, 9)), Color("526b75"))
	for cell in menu_preview.snake:
		draw_rect(Rect2(origin + Vector2(cell) * 11 + Vector2.ONE, Vector2(9, 9)), GREEN)
	words("BEST  %d" % endless_bests[selected_stage] if unlocked else "LOCKED · Clear this stage in Campaign", Vector2(743, 559), 13, INK if unlocked else MUTED, true)
	var targets: Array[int] = Rules.medal_targets(selected_stage)
	var rank: int = Rules.medal_rank(selected_stage, endless_bests[selected_stage])
	for i in range(3):
		var x := 770.0 + i * 113
		medal_badge(Vector2(x, 590), i, unlocked and i < rank)
		words(MEDAL_NAMES[i], Vector2(x - 23, 624), 12, MEDAL_COLORS[i], true)
		words(str(targets[i]) + " pts", Vector2(x - 23, 646), 12, MUTED)
	words("Fixed pace. No quota. Keep scoring.", Vector2(721, 767), 13, MUTED)

func draw_board() -> void:
	panel(Rect2(40, 206, 640, 536), Color("20333c"), 16, LINE)
	panel(Rect2(48, 214, 624, 520), Color("13232b"), 8)
	for y in range(Rules.HEIGHT):
		for x in range(Rules.WIDTH):
			draw_circle(BOARD + Vector2(x + 0.5, y + 0.5) * CELL, 1.0, Color("29404a"))
	for wall in game.walls:
		var p := BOARD + Vector2(wall) * CELL
		panel(Rect2(p + Vector2(2, 2), Vector2(22, 22)), Color("425660"), 4, Color("5a7078"))
		draw_line(p + Vector2(8, 11), p + Vector2(15, 11), Color("7f9399"), 2.0)
	if game.mode == "adventure":
		var exit_pos: Vector2 = BOARD + Vector2(game.exit_cell) * CELL
		panel(Rect2(exit_pos + Vector2.ONE, Vector2(24, 24)), BLUE, 4)
		words("E", exit_pos + Vector2(7, 19), 17, BG, true)
		for cell in game.adventure_foods:
			draw_food(cell)
		for cell in game.adventure_pickups:
			draw_pickup(cell, game.adventure_pickups[cell])
	else:
		if game.food.x >= 0:
			draw_food(game.food)
		if game.pickup_kind != "":
			draw_pickup(game.pickup, game.pickup_kind)
	if game.shield:
		draw_snake_shield()
	for i in range(game.snake.size() - 1, -1, -1):
		var p: Vector2 = BOARD + Vector2(game.snake[i]) * CELL
		var color := GREEN if i == 0 else Color("89bb60").lerp(Color("b8e870"), 1.0 - float(i) / game.snake.size())
		panel(Rect2(p + Vector2(1.5, 1.5), Vector2(23, 23)), color, 6)
		if i == 0:
			var front: Vector2 = Vector2(game.direction) * 5
			var side := Vector2(-game.direction.y, game.direction.x) * 5
			var center := p + Vector2(13, 13)
			draw_circle(center + front + side, 2.5, BG)
			draw_circle(center + front - side, 2.5, BG)

func draw_snake_shield() -> void:
	# Layer joined capsules to form one continuous envelope, including bends and tail.
	var points := PackedVector2Array()
	for cell in game.snake:
		points.append(BOARD + Vector2(cell) * CELL + Vector2.ONE * CELL / 2.0)
	var widths := [40.0, 32.0, 28.0]
	var colors := [Color(BLUE, 0.10 + sin(clock_time * 2.0) * 0.025), BLUE, Color("1b4148")]
	for layer in range(widths.size()):
		if points.size() > 1:
			draw_polyline(points, colors[layer], widths[layer], true)
		for point in points:
			draw_circle(point, widths[layer] / 2.0, colors[layer], true, -1.0, true)

func draw_sidebar() -> void:
	if game.mode == "adventure":
		draw_adventure_sidebar()
		return
	var data: Dictionary = Rules.STAGES[game.stage]
	words("ENDLESS CHALLENGE" if game.mode == "endless" else "THE JOURNEY", Vector2(720, 177), 11, MUTED, true)
	panel(Rect2(720, 206, 340, 195), PANEL, 14, LINE)
	if game.state == "shield_save":
		words("SHIELD USED · TIME STOPPED", Vector2(741, 241), 11, BLUE, true)
		words("A second chance.", Vector2(741, 278), 25, INK, true)
		words("Choose a safe direction to continue.", Vector2(741, 314), 14, MUTED)
		words("↑   ↓   ←   →    or WASD", Vector2(741, 350), 20, BLUE, true)
		words("Trapped? Press R for a new run.", Vector2(741, 382), 12, MUTED)
	else:
		words("%02d" % (game.stage + 1), Vector2(741, 241), 13, GREEN, true)
		words("PACE  %.2f×" % (Rules.BASE_INTERVAL / game.interval()), Vector2(956, 241), 11, MUTED, true)
		words(data.name, Vector2(741, 275), 27, INK, true)
		words(data.subtitle, Vector2(741, 301), 15, MUTED)
		if game.mode == "endless":
			var rank: int = Rules.medal_rank(game.stage, game.score)
			var targets: Array[int] = Rules.medal_targets(game.stage)
			var target: int = targets[mini(rank, 2)]
			words("GOLD EARNED · KEEP GOING" if rank == 3 else "NEXT · " + MEDAL_NAMES[rank].to_upper(), Vector2(741, 337), 11, GOLD if rank == 3 else MUTED, true)
			if rank < 3:
				words("%d pts" % target, Vector2(972, 337), 12, INK, true)
			panel(Rect2(741, 351, 296, 7), LINE, 3)
			panel(Rect2(741, 351, 296 * clampf(float(game.score) / target, 0.0, 1.0), 7), MEDAL_COLORS[mini(rank, 2)], 3)
			words("%d bites · length %d · no finish line" % [game.eaten, game.snake.size()], Vector2(741, 384), 12, GREEN)
		else:
			words("FOOD COLLECTED", Vector2(741, 337), 11, MUTED, true)
			words("%d / %d" % [game.eaten, data.goal], Vector2(986, 337), 14, INK, true)
			for i in range(int(data.goal)):
				var width: float = 297.0 / float(data.goal)
				panel(Rect2(741 + i * width, 351, width - 5, 7), GREEN if i < game.eaten else LINE, 3)
			words("Clear bonus  +%d" % (100 * (game.stage + 1)), Vector2(741, 384), 12, GREEN)
	words("A LITTLE HELP", Vector2(720, 432), 11, MUTED, true)
	power_row(449, "S", "Shield", "Stops one collision. Choose a safe turn.", BLUE, game.shield, "shield")
	power_row(522, "−", "Shed", "Lose 30% of your length. Minimum 3.", LILAC, false, "shed")
	power_row(595, "+", "Bonus bite", "An instant 50-point boost.", GOLD, false, "bonus")
	var note := "Look for power-ups as you collect food."
	if game.pickup_kind != "":
		note = "Pickup disappears in %ds" % ceili(game.pickup_time)
	words(note, Vector2(721, 695), 13, MUTED)
	if game.mode == "endless":
		var rank: int = Rules.medal_rank(game.stage, game.score)
		for i in range(3):
			var x := 733.0 + i * 113
			medal_badge(Vector2(x, 725), i, i < rank)
			words(MEDAL_NAMES[i], Vector2(x + 18, 729), 12, MEDAL_COLORS[i] if i < rank else MUTED, true)
		return
	for i in range(Rules.STAGES.size()):
		var x := 737.0 + i * 34.0
		if i < Rules.STAGES.size() - 1:
			draw_line(Vector2(x, 725), Vector2(x + 34, 725), GREEN if i < game.stage else LINE, 1.0)
		draw_circle(Vector2(x, 725), 12.0, GREEN if i == game.stage else PANEL)
		draw_arc(Vector2(x, 725), 12.0, 0, TAU, 24, GREEN if i <= game.stage else LINE, 1.0, true)
		var label := str(i + 1)
		var text_width := bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		words(label, Vector2(x - text_width / 2, 729), 10, BG if i == game.stage else (GREEN if i < game.stage else MUTED), true)

func power_row(y: float, symbol: String, title: String, description: String, color: Color, active: bool, kind: String) -> void:
	var feedback: Dictionary = pickup_feedback.get(kind, {})
	var strength := clampf(float(feedback.get("remaining", 0.0)) / 0.6, 0.0, 1.0)
	panel(Rect2(720, y, 340, 64), PANEL.lerp(color, strength * 0.10), 10, color if active else LINE.lerp(color, strength))
	panel(Rect2(734, y + 15, 34, 34), color, 9)
	words(symbol, Vector2(745, y + 39), 18, BG, true)
	words(title, Vector2(781, y + 26), 16, INK, true)
	words(str(feedback.get("text", description)), Vector2(781, y + 47), 11, MUTED.lerp(color, strength))
	if active:
		draw_circle(Vector2(1041, y + 20), 3, color)

func draw_overlay() -> void:
	if game.state == "adventure_clear":
		draw_adventure_result()
		return
	if game.state == "shield_save":
		# Keep every board cell visible while the player chooses an escape.
		draw_style_box(box(Color.TRANSPARENT, 16, BLUE), Rect2(40, 206, 640, 536))
		return
	draw_style_box(box(Color(0.045, 0.08, 0.11, 0.80), 8), Rect2(48, 214, 624, 520))
	panel(Rect2(99, 319, 522, 267), Color("1b3038"), 18, Color("405650"))
	var eyebrow := "READY WHEN YOU ARE"
	var title := "One more bite."
	var line1 := "Eat. Grow. Find your way through %d stages." % Rules.STAGES.size()
	var line2 := "Arrow keys or WASD to steer. Don't hit the walls."
	match game.state:
		"paused":
			eyebrow = "TAKE A BREATHER"
			title = "On pause."
			line1 = "Your snake will be right here."
			line2 = "Press Space or choose Resume to keep going."
		"stage_clear":
			eyebrow = "STAGE %02d COMPLETE" % (game.stage + 1)
			title = "Looking sharp."
			line1 = "+%d clear bonus · %d points so far" % [100 * (game.stage + 1), game.score]
			line2 = "Endless arena unlocked. Next: " + str(Rules.STAGES[game.stage + 1].name) + "."
		"game_over":
			eyebrow = "EVERY RUN IS A FRESH START"
			title = "That's a wrap."
			line1 = game.crash_reason + "  Score: %d" % game.score
			line2 = "Take another run at your personal best."
			if game.mode == "adventure":
				eyebrow = "ADVENTURE · MAZE %02d" % (game.stage + 1)
				line2 = "Reach the exit to bank your score and earn a medal."
			if game.mode == "endless":
				var rank: int = Rules.medal_rank(game.stage, game.score)
				eyebrow = "ENDLESS · " + str(Rules.STAGES[game.stage].name).to_upper()
				line2 = (MEDAL_NAMES[rank - 1] + " medal" if rank > 0 else "No medal yet") + " · arena best %d" % current_best()
		"victory":
			eyebrow = "ALL %d STAGES COMPLETE" % Rules.STAGES.size()
			title = "A clean sweep."
			line1 = "%d points · %d bites · one excellent snake" % [game.score, game.total_food]
			line2 = "All 10 Endless arenas are unlocked."
		"shield_save":
			eyebrow = "SHIELD USED"
			title = "A second chance."
			line1 = "Time has stopped. Pick a safe direction to continue."
			line2 = "Use an arrow key or WASD. R starts a new run."
	centered(eyebrow, 356, 11, GREEN, true)
	centered(title, 404, 37, INK, true)
	centered(line1, 443, 16, INK)
	centered(line2, 469, 13, MUTED)
	if game.state != "shield_save":
		centered("or press Enter", 577, 11, MUTED)
	else:
		centered("↑   ↓   ←   →", 543, 27, BLUE, true)

func draw_food(cell: Vector2i) -> void:
	var p := BOARD + Vector2(cell) * CELL + Vector2.ONE * 13
	draw_circle(p, 13.0 + sin(clock_time * 4) * 1.5, Color(1.0, 0.76, 0.35, 0.09))
	draw_circle(p, 8, GOLD)
	draw_circle(p + Vector2(-2, -2), 2, Color("fff0bd"))
	draw_line(p + Vector2(0, -8), p + Vector2(3, -12), GREEN, 2.0, true)

func draw_pickup(cell: Vector2i, kind: String) -> void:
	var p := BOARD + Vector2(cell) * CELL + Vector2.ONE * 13
	var color := GOLD if kind == "bonus" else (LILAC if kind == "shed" else BLUE)
	draw_circle(p, 11, color)
	words({"shield": "S", "shed": "−", "bonus": "+"}[kind], p + Vector2(-5, 5), 14, BG, true)

func draw_adventure_menu() -> void:
	words("Reach the exit. Race the clock. Finish with a longer snake.", Vector2(48, 237), 15, MUTED)
	words("7 MAZES · ALL OPEN TO PLAY", Vector2(720, 190), 12, BLUE, true)
	for i in range(Rules.ADVENTURES.size()):
		var bounds := arena_bounds(i)
		var selected := i == selected_stage
		panel(bounds, Color("20313a") if selected else PANEL, 10, BLUE if selected else LINE)
		words("%02d" % (i + 1), bounds.position + Vector2(15, 27), 12, BLUE, true)
		words(Rules.ADVENTURES[i].name, bounds.position + Vector2(46, 27), 17, INK, true)
		words("BEST  %d" % adventure_bests[i] if adventure_bests[i] > 0 else "Ready to explore", bounds.position + Vector2(16, 57), 12, MUTED)
		var maze_rank: int = Rules.adventure_medal_rank(i, adventure_bests[i])
		for medal in range(3):
			medal_badge(bounds.position + Vector2(218 + medal * 30, 52), medal, medal < maze_rank, 9)
	words("Finish +1,000 · speed up to +1,000", Vector2(48, 676), 16, INK, true)
	words("Food +25 · extra length +75 per segment at the exit", Vector2(48, 701), 14, MUTED)
	words("Shield and Bonus pickups. Your length only grows.", Vector2(48, 726), 14, GREEN)
	words("Arrow keys select · Enter starts", Vector2(48, 765), 13, MUTED)
	panel(Rect2(720, 226, 340, 448), PANEL, 14, LINE)
	var data: Dictionary = Rules.ADVENTURES[selected_stage]
	words("ADVENTURE MAZE %02d" % (selected_stage + 1), Vector2(743, 256), 11, BLUE, true)
	words(data.name, Vector2(743, 287), 25, INK, true)
	var origin := Vector2(758, 309)
	panel(Rect2(origin - Vector2(5, 5), Vector2(274, 230)), BG, 8, LINE)
	for wall in menu_preview.walls:
		draw_rect(Rect2(origin + Vector2(wall) * 11 + Vector2.ONE, Vector2(9, 9)), Color("526b75"))
	for cell in menu_preview.adventure_foods:
		draw_circle(origin + Vector2(cell) * 11 + Vector2(5.5, 5.5), 2.5, GOLD)
	for cell in menu_preview.snake:
		draw_rect(Rect2(origin + Vector2(cell) * 11 + Vector2.ONE, Vector2(9, 9)), GREEN)
	draw_rect(Rect2(origin + Vector2(menu_preview.exit_cell) * 11, Vector2(11, 11)), BLUE)
	words("FULL SPEED BONUS  ≤ %ds" % data.par, Vector2(743, 557), 12, INK, true)
	var targets: Array[int] = Rules.adventure_medal_targets(selected_stage)
	var rank: int = Rules.adventure_medal_rank(selected_stage, adventure_bests[selected_stage])
	for i in range(3):
		var x := 770.0 + i * 113
		medal_badge(Vector2(x, 590), i, i < rank)
		words(MEDAL_NAMES[i], Vector2(x - 23, 624), 12, MEDAL_COLORS[i], true)
		words(str(targets[i]) + " pts", Vector2(x - 23, 646), 12, MUTED)
	var fastest := adventure_times[selected_stage]
	words("FASTEST FINISH  %.2fs" % fastest if fastest > 0.0 else "Cyan E = exit · gold dots = food", Vector2(721, 767), 13, MUTED)

func draw_adventure_sidebar() -> void:
	var data: Dictionary = Rules.ADVENTURES[game.stage]
	words("ADVENTURE · FIND THE EXIT", Vector2(720, 177), 11, BLUE, true)
	panel(Rect2(720, 206, 340, 195), PANEL, 14, LINE)
	words("MAZE %02d" % (game.stage + 1), Vector2(741, 241), 12, BLUE, true)
	words("PACE %.2f×" % (Rules.BASE_INTERVAL / game.interval()), Vector2(956, 241), 11, MUTED, true)
	words(data.name, Vector2(741, 275), 27, INK, true)
	words("TIME  %.2fs" % game.run_time, Vector2(741, 316), 24, GOLD, true)
	words("Full speed bonus at %ds or faster" % data.par, Vector2(741, 346), 14, MUTED)
	words("LENGTH %d    ·    FOOD %d / %d" % [game.snake.size(), game.eaten, data.food_count], Vector2(741, 382), 13, GREEN, true)
	words("ALONG THE WAY", Vector2(720, 432), 11, MUTED, true)
	power_row(449, "S", "Shield", "Stops one collision. Choose a safe turn.", BLUE, game.shield, "shield")
	power_row(522, "+", "Bonus bite", "An instant 50-point boost.", GOLD, false, "bonus")
	panel(Rect2(720, 601, 340, 95), PANEL, 10, LINE)
	if game.state == "shield_save":
		words("SHIELD USED · TIME STOPPED", Vector2(739, 626), 12, BLUE, true)
		words("Choose a safe arrow / WASD direction.", Vector2(739, 652), 14, INK)
		words("Trapped? R restarts this maze.", Vector2(739, 676), 12, MUTED)
	else:
		words("AT THE EXIT", Vector2(739, 625), 11, BLUE, true)
		words("Finish +1,000    Speed +%d" % game.adventure_time_bonus(), Vector2(739, 651), 14, INK)
		words("Length bonus +%d · 75 per extra segment" % ((game.snake.size() - 4) * 75), Vector2(739, 677), 12, GREEN)
	var projected: int = game.score if game.state == "adventure_clear" else game.score + 1000 + game.adventure_time_bonus() + (game.snake.size() - 4) * 75
	var targets: Array[int] = Rules.adventure_medal_targets(game.stage)
	for i in range(3):
		var x := 733.0 + i * 113
		medal_badge(Vector2(x, 722), i, projected >= targets[i])
		words(str(targets[i]), Vector2(x + 17, 727), 12, MEDAL_COLORS[i], true)
	words("Projected medals · bank them at the exit", Vector2(721, 752), 12, MUTED)

func draw_adventure_result() -> void:
	draw_style_box(box(Color(0.045, 0.08, 0.11, 0.85), 8), Rect2(48, 214, 624, 520))
	panel(Rect2(99, 278, 522, 339), Color("1b3038"), 18, BLUE)
	var rank: int = Rules.adventure_medal_rank(game.stage, game.score)
	centered("MAZE %02d COMPLETE" % (game.stage + 1), 312, 11, BLUE, true)
	centered(MEDAL_NAMES[rank - 1] + " medal!", 354, 35, MEDAL_COLORS[rank - 1], true)
	centered("%d points · %.2fs · length %d" % [game.score, game.run_time, game.snake.size()], 390, 20, INK, true)
	centered("Finish +%d   Speed +%d   Length +%d" % [game.finish_bonus, game.time_bonus, game.length_bonus], 421, 14, GREEN)
	centered("Food & pickups +%d" % (game.score - game.finish_bonus - game.time_bonus - game.length_bonus), 445, 14, MUTED)
	centered("Best %d pts · fastest %.2fs" % [current_best(), adventure_times[game.stage]], 480, 14, GOLD)
	centered("Enter continues · R replays", 552, 12, MUTED)
