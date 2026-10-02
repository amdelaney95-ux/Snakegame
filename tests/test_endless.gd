extends SceneTree

const Rules = preload("res://scripts/snake_game.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1100, 820)
	var game = Rules.new()
	for arena in range(10):
		game.start("endless", arena)
		var pace: float = game.interval()
		for bite in range(int(Rules.STAGES[arena].goal) + 3):
			game.snake.assign([Vector2i(6, 10), Vector2i(5, 10), Vector2i(4, 10)])
			game.food = Vector2i(7, 10)
			game.step()
		check(game.state == "playing" and game.stage == arena, "no quota or transition in arena " + str(arena))
		check(game.score == (int(Rules.STAGES[arena].goal) + 3) * 10 * (arena + 1), "endless food points, no clear bonus")
		game.tick_effects(50.0)
		check(is_equal_approx(game.interval(), pace), "endless speed stays fixed")
		var targets: Array[int] = Rules.medal_targets(arena)
		for rank in range(3):
			check(Rules.medal_rank(arena, targets[rank] - 1) == rank, "below medal threshold")
			check(Rules.medal_rank(arena, targets[rank]) == rank + 1, "exact medal threshold")
		check(Rules.medal_rank(arena, 0) == 0, "no medal for zero score")
	game.start("endless", 5)
	game.score = 800
	game.start("endless", 5)
	check(game.stage == 5 and game.score == 0 and game.snake.size() == 4, "retry same arena")
	game.start()
	check(game.mode == "campaign" and game.stage == 0, "switch back to campaign")
	game.start("endless", 0)
	game.snake.clear()
	for y in range(Rules.HEIGHT):
		for n in range(Rules.WIDTH):
			var x: int = n if y % 2 == 0 else Rules.WIDTH - 1 - n
			if Vector2i(x, y) != Vector2i.ZERO:
				game.snake.append(Vector2i(x, y))
	game.direction = Vector2i.LEFT
	game.food = Vector2i.ZERO
	check(game.step() == "board_full" and game.state == "playing", "full board keeps endless running")
	check(game.snake.size() == 336 and not game.snake.has(game.food) and game.food != Vector2i(-1, -1), "full board safely frees food space")
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.set_process(false)
	ui.muted = true
	ui.best = 3340
	ui.cleared_count = 0
	ui.endless_bests.fill(0)
	ui.select_mode("endless")
	check(ui.action_button.disabled and ui.arena_buttons[0].disabled, "fresh profile cannot play uncleared arena")
	ui.primary_action()
	check(ui.game.state == "title", "locked arena launch blocked")
	ui.select_mode("campaign")
	ui.primary_action()
	ui.game.eaten = 4
	ui.game.food = Vector2i(7, 10)
	ui.handle_event(ui.game.step())
	check(ui.cleared_count == 1, "campaign clear unlocks arena immediately")
	ui.show_menu()
	ui.select_mode("endless")
	check(not ui.action_button.disabled and not ui.arena_buttons[0].disabled and ui.arena_buttons[1].disabled, "only cleared arena selectable")
	ui.primary_action()
	check(ui.game.mode == "endless" and ui.game.state == "playing", "endless launch")
	ui.game.score = 350
	ui.handle_event("food")
	check(ui.endless_bests[0] == 350 and ui.best == 3340 and ui.cleared_count == 1, "endless saves silver without changing campaign best or unlocks")
	ui.game.score = 200
	ui.handle_event("food")
	check(ui.endless_bests[0] == 350, "lower runs cannot downgrade best or medal")
	ui.cleared_count = 6
	ui.show_menu()
	ui.select_arena(5)
	ui.primary_action()
	ui.game.score = 3900
	ui.handle_event("bonus")
	check(ui.endless_bests[5] == 3900 and ui.endless_bests[0] == 350 and ui.endless_bests[1] == 0, "arena records stay separate")
	ui.game.state = "game_over"
	ui.primary_action()
	check(ui.game.mode == "endless" and ui.game.stage == 5 and ui.game.score == 0, "game over replays selected arena")
	ui.save_progress()
	var reloaded = load("res://main.tscn").instantiate()
	root.add_child(reloaded)
	reloaded.set_process(false)
	check(reloaded.best == 3340 and reloaded.cleared_count == 6, "campaign persistence")
	check(reloaded.endless_bests[0] == 350 and reloaded.endless_bests[5] == 3900, "endless persistence")
	check(Rules.medal_rank(5, reloaded.endless_bests[5]) == 3, "gold medal restored")
	ui.legacy_restore_pending = true
	ui.cleared_count = 0
	ui.show_menu()
	ui.open_restore()
	ui.change_restore(6)
	ui.confirm_restore()
	check(ui.cleared_count == 6 and not ui.legacy_restore_pending and ui.best == 3340, "one-time restore preserves old scores")
	check(ui.menu_mode == "endless" and ui.selected_stage == 5, "restored player enters arena selection")
	ui.free()
	reloaded.free()
	await process_frame
	print("ENDLESS CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)

