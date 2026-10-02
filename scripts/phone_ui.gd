extends RefCounted
## Phone presentation and gestures share the desktop game's rules and saves.
var ui
var width := 390.0
var height := 700.0
var landscape := false
var board_rect := Rect2()
var direction_rects: Dictionary = {}
var swipe_origins: Dictionary = {}
const DIRECTIONS := [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]
const SYMBOLS := ["↑", "←", "↓", "→"]

func _init(owner_ui) -> void:
	ui = owner_ui

func configure(dimensions: Vector2) -> void:
	width = dimensions.x
	height = dimensions.y
	landscape = width > height
	if landscape:
		var board_height := minf(height - 94.0, (width * 0.59 - 24.0) / 1.2)
		board_rect = Rect2(16, 78, board_height * 1.2, board_height)
	else:
		var board_height := minf((width - 28.0) / 1.2, height - 335.0)
		board_rect = Rect2((width - board_height * 1.2) / 2.0, 153, board_height * 1.2, board_height)
	var center_x := width - (width - board_rect.end.x) * 0.5 if landscape else width / 2.0
	var top := 165.0 if landscape else height - 148.0
	direction_rects = {
		Vector2i.UP: Rect2(center_x - 31, top, 62, 62),
		Vector2i.LEFT: Rect2(center_x - 99, top + 68, 62, 62),
		Vector2i.DOWN: Rect2(center_x - 31, top + 68, 62, 62),
		Vector2i.RIGHT: Rect2(center_x + 37, top + 68, 62, 62),
	}
	swipe_origins.clear()

func set_button(button: Button, bounds: Rect2, font_size: int = 15) -> void:
	button.position = bounds.position
	button.size = bounds.size
	button.add_theme_font_size_override("font_size", font_size)

func card_bounds(index: int) -> Rect2:
	var columns := 4 if landscape else 2
	var card_width := (width - 24.0 - (columns - 1) * 8.0) / columns
	var card_height := 46.0 if landscape else 50.0
	return Rect2(12 + (index % columns) * (card_width + 8), 124 + floori(float(index) / columns) * (card_height + 8), card_width, card_height)

func arrange() -> void:
	var menu: bool = ui.game.state == "title"
	set_button(ui.mute_button, Rect2(width - 108, 12, 96, 42), 13)
	set_button(ui.menu_button, Rect2(12, 62, 83, 44))
	set_button(ui.pause_button, Rect2(width - 95, 62, 83, 44))
	set_button(ui.restart_button, Rect2(width / 2 - 43, 62, 86, 44))
	ui.restart_button.text = "Retry"
	if landscape and not menu:
		set_button(ui.menu_button, Rect2(width - 298, 62, 88, 44))
		set_button(ui.restart_button, Rect2(width - 200, 62, 88, 44))
		set_button(ui.pause_button, Rect2(width - 102, 62, 90, 44))
	var tabs := [ui.campaign_tab, ui.endless_tab, ui.adventure_tab]
	for i in range(3):
		set_button(tabs[i], Rect2(12 + i * (width - 24) / 3, 66, (width - 24) / 3 - 5, 44), 14)
	for i in range(ui.arena_buttons.size()):
		set_button(ui.arena_buttons[i], card_bounds(i))
	if menu:
		set_button(ui.action_button, Rect2(16, height - 64, width - 32, 48), 17)
		if ui.legacy_restore_pending and ui.menu_mode == "campaign":
			set_button(ui.restore_button, Rect2(16, height - 114, width - 32, 42), 14)
	else:
		var x := board_rect.end.x + 24 if landscape else 24.0
		var y := 212.0 if landscape else board_rect.end.y + 48.0
		var button_width := width - x - 24 if landscape else width - 48
		set_button(ui.action_button, Rect2(x, y, button_width, 48), 16)
		set_button(ui.replay_button, Rect2(x, y + 60, button_width, 46))
		if ui.phone_ready:
			ui.action_button.text = "Go!   →"
			ui.pause_button.disabled = true
	if ui.restore_open:
		var center_y := height * 0.53
		set_button(ui.restore_minus, Rect2(width / 2 - 120, center_y, 56, 48), 23)
		set_button(ui.restore_plus, Rect2(width / 2 + 64, center_y, 56, 48), 23)
		set_button(ui.restore_confirm, Rect2(20, center_y + 64, width - 40, 48), 16)
		set_button(ui.restore_cancel, Rect2(width / 2 - 55, center_y + 122, 110, 44))
	for button in [ui.action_button, ui.replay_button]:
		button.text = button.text.replace("→", "").strip_edges()

func draw() -> void:
	ui.draw_rect(Rect2(0, 0, width, height), ui.BG)
	ui.words("snake stages", Vector2(15, 41), 28, ui.GREEN, true)
	if ui.restore_open:
		draw_restore()
	elif ui.game.state == "title":
		draw_menu()
	else:
		draw_play()

func draw_menu() -> void:
	var adventure: bool = ui.menu_mode == "adventure"
	var endless: bool = ui.menu_mode == "endless"
	var levels: Array = ui.Rules.ADVENTURES if adventure else ui.Rules.STAGES
	for i in range(levels.size()):
		var r := card_bounds(i)
		var selected: bool = ui.menu_mode != "campaign" and i == ui.selected_stage
		var locked: bool = endless and i >= ui.cleared_count
		ui.panel(r, ui.PANEL, 8, ui.GREEN if selected else ui.LINE)
		ui.words("%02d" % (i + 1), r.position + Vector2(9, 19), 10, ui.GREEN)
		ui.words(levels[i].name, r.position + Vector2(30, 19), 13, ui.MUTED if locked else ui.INK, true)
		var label := "Clear in Campaign" if locked else "Ready to play"
		if ui.menu_mode == "campaign":
			label = "Cleared" if i < ui.cleared_count else "Stage %d" % (i + 1)
		elif not locked:
			var points: int = ui.adventure_bests[i] if adventure else ui.endless_bests[i]
			var rank: int = ui.Rules.adventure_medal_rank(i, points) if adventure else ui.Rules.medal_rank(i, points)
			label = (ui.MEDAL_NAMES[rank - 1] + " · " if rank > 0 else "Best · ") + str(points)
		ui.words(label, r.position + Vector2(10, 38), 11, ui.MUTED)
	var y := card_bounds(levels.size() - 1).end.y + 22.0
	if adventure:
		var data: Dictionary = levels[ui.selected_stage]
		var targets: Array[int] = ui.Rules.adventure_medal_targets(ui.selected_stage)
		ui.words("Exit +1,000 · fast +1,000 · extra length +75", Vector2(14, y), 12, ui.INK)
		ui.words("B %d   S %d   G %d   ·   Par %ds" % [targets[0], targets[1], targets[2], data.par], Vector2(14, y + 20), 12, ui.GOLD)
		if not landscape and y + 64 < height - 75:
			ui.words("Food +25. Shield and Bonus. No shrinking.", Vector2(14, y + 42), 12, ui.MUTED)
	elif endless:
		var targets: Array[int] = ui.Rules.medal_targets(ui.selected_stage)
		ui.words("B %d   ·   S %d   ·   G %d" % [targets[0], targets[1], targets[2]], Vector2(14, y), 13, ui.GOLD)
		ui.words("Fixed pace. Keep growing and scoring.", Vector2(14, y + 20), 12, ui.MUTED)
	else:
		ui.words("%d / 10 cleared · Best %d" % [ui.cleared_count, ui.best], Vector2(14, y), 13, ui.GOLD)
		if not ui.legacy_restore_pending:
			ui.words("Ten stages. Shield, Shed, and Bonus pickups.", Vector2(14, y + 20), 12, ui.MUTED)

func draw_play() -> void:
	var game = ui.game
	var adventure: bool = game.mode == "adventure"
	var data: Dictionary = ui.Rules.ADVENTURES[game.stage] if adventure else ui.Rules.STAGES[game.stage]
	var stats_y := 64.0 if landscape else 131.0
	ui.words("%s %02d · %s" % ["Maze" if adventure else "Stage", game.stage + 1, data.name], Vector2(16, stats_y), 13, ui.INK, true)
	if not landscape:
		ui.words("%d pts" % game.score + ("   %.1fs" % game.run_time if adventure else "   Best %d" % ui.current_best()), Vector2(16, stats_y + 17), 12, ui.GOLD)
	var factor := board_rect.size.x / 624.0
	ui.draw_set_transform(board_rect.position - Vector2(48, 214) * factor, 0.0, Vector2.ONE * factor)
	ui.draw_board()
	ui.draw_set_transform(Vector2.ZERO)
	var info_x := board_rect.end.x + 24 if landscape else 16.0
	var info_y := 128.0 if landscape else board_rect.end.y + 25
	var info := ""
	if ui.phone_ready:
		info = "Ready? Check the board, then tap Go."
	elif game.state == "shield_save":
		info = "Shield used! Choose a safe direction."
	elif not ui.pickup_feedback.is_empty():
		info = str(ui.pickup_feedback.values().back().text)
	elif adventure:
		info = "%.1fs · Length %d · Find the cyan E" % [game.run_time, game.snake.size()]
	elif game.mode == "endless":
		info = "%d pts · Length %d · Keep going" % [game.score, game.snake.size()]
	else:
		info = "Food %d / %d · Length %d" % [game.eaten, data.goal, game.snake.size()]
	ui.words(info, Vector2(info_x, info_y), 12, ui.BLUE if game.state == "shield_save" else ui.INK)
	if game.shield:
		ui.words("SHIELD READY", Vector2(info_x, info_y + 18), 10, ui.BLUE, true)
	if game.state in ["playing", "shield_save"]:
		for i in range(DIRECTIONS.size()):
			var r: Rect2 = direction_rects[DIRECTIONS[i]]
			ui.panel(r, ui.PANEL, 14, ui.LINE)
			var direction := Vector2(DIRECTIONS[i])
			var side := Vector2(-direction.y, direction.x)
			var center := r.get_center()
			var tip := center + direction * 16
			ui.draw_line(center - direction * 15, tip, ui.GREEN, 3.0, true)
			ui.draw_line(tip, center + direction * 6 + side * 10, ui.GREEN, 3.0, true)
			ui.draw_line(tip, center + direction * 6 - side * 10, ui.GREEN, 3.0, true)
		if landscape:
			ui.words("Tap arrows or swipe on the board", Vector2(info_x, 329), 12, ui.MUTED)
	elif not ui.phone_ready:
		draw_result()

func draw_result() -> void:
	var game = ui.game
	var r := board_rect
	ui.draw_rect(r, Color(0.04, 0.08, 0.11, 0.91))
	var title := "Paused"
	var lines: Array[String] = ["Your snake is waiting.", "Tap Resume when you are ready."]
	match game.state:
		"adventure_clear":
			var rank: int = ui.Rules.adventure_medal_rank(game.stage, game.score)
			title = ui.MEDAL_NAMES[rank - 1] + " medal!"
			lines = ["%d points · %.2fs" % [game.score, game.run_time], "Length %d · bonus +%d" % [game.snake.size(), game.length_bonus], "Finish +1,000 · speed +%d" % game.time_bonus]
		"stage_clear":
			title = "Stage cleared!"
			lines = ["%d points · bonus +%d" % [game.score, 100 * (game.stage + 1)], "New Endless arena unlocked."]
		"victory":
			title = "A clean sweep!"
			lines = ["All ten stages complete.", "%d points" % game.score]
		"game_over":
			title = "Try again?"
			lines = [game.crash_reason, "%d points" % game.score]
			if game.mode == "adventure":
				lines.append("Reach the exit to bank your score.")
			elif game.mode == "endless":
				var rank: int = ui.Rules.medal_rank(game.stage, game.score)
				lines.append(ui.MEDAL_NAMES[rank - 1] + " medal" if rank > 0 else "Keep chasing your next medal.")
	var y := r.position.y + r.size.y / 2 - 32
	ui.words(title, Vector2(r.position.x + 16, y), 26, ui.GREEN, true)
	for i in range(lines.size()):
		ui.words(lines[i], Vector2(r.position.x + 16, y + 30 + i * 23), 13, ui.INK)

func draw_restore() -> void:
	ui.words("Restore earlier progress", Vector2(20, 115), 22, ui.GREEN, true)
	ui.words("Choose the highest stage you already cleared.", Vector2(20, 148), 13, ui.INK)
	ui.words("Your existing high score will stay the same.", Vector2(20, 174), 13, ui.MUTED)
	ui.words(str(ui.restore_selection), Vector2(width / 2 - 13, height * 0.53 + 35), 34, ui.GOLD, true)

func handle_input(event: InputEvent) -> void:
	if ui.game.state not in ["playing", "shield_save"]:
		swipe_origins.clear()
		return
	var inverse: Transform2D = ui.get_global_transform_with_canvas().affine_inverse()
	if event is InputEventScreenTouch:
		var point: Vector2 = inverse * event.position
		if event.pressed:
			if press_direction(point):
				ui.get_viewport().set_input_as_handled()
			elif board_rect.has_point(point):
				swipe_origins[event.index] = point
		else:
			swipe_origins.erase(event.index)
	elif event is InputEventScreenDrag and swipe_origins.has(event.index):
		var point: Vector2 = inverse * event.position
		var delta: Vector2 = point - swipe_origins[event.index]
		if delta.length() >= 18.0:
			ui.steer(Vector2i(int(signf(delta.x)), 0) if absf(delta.x) > absf(delta.y) else Vector2i(0, int(signf(delta.y))))
			swipe_origins[event.index] = point
			ui.get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != -1 and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if press_direction(inverse * event.position):
			ui.get_viewport().set_input_as_handled()

func press_direction(point: Vector2) -> bool:
	for direction in direction_rects:
		if direction_rects[direction].has_point(point):
			ui.steer(direction)
			return true
	return false
