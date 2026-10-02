extends SceneTree
## Run only with an isolated APPDATA: persistence cases write fixture progress.
const Rules = preload("res://scripts/snake_game.gd")
const DIRS := {"R": Vector2i.RIGHT, "L": Vector2i.LEFT, "U": Vector2i.UP, "D": Vector2i.DOWN}
var checks := 0
var failures := 0
var routes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/adventure_routes.json"))

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func shortest_path(game) -> Array[Vector2i]:
	var start: Vector2i = game.snake[0]
	var queue: Array[Vector2i] = [start]
	var previous := {start: start}
	for cell in queue:
		if cell == game.exit_cell:
			var result: Array[Vector2i] = []
			var current: Vector2i = cell
			while current != start:
				result.push_front(current)
				current = previous[current]
			return result
		for dir in DIRS.values():
			var next: Vector2i = cell + dir
			if next.x < 0 or next.y < 0 or next.x >= Rules.WIDTH or next.y >= Rules.HEIGHT:
				continue
			if game.walls.has(next) or game.snake.has(next) or previous.has(next):
				continue
			previous[next] = cell
			queue.append(next)
	return []

func follow_route(game, route: String) -> void:
	for letter in route:
		game.queue_turn(DIRS[letter])
		game.tick_effects(game.interval())
		game.step()
		if game.state != "playing":
			break

func run() -> void:
	root.size = Vector2i(1100, 820)
	var last_shortest := 0
	var last_interval := 1.0
	for level in range(Rules.ADVENTURES.size()):
		var game = Rules.new()
		game.start("adventure", level)
		var start_walls: Array = game.walls.duplicate()
		var start_food: Array = game.adventure_foods.duplicate()
		check(game.stage == level and game.mode == "adventure", "selected maze starts")
		check(game.adventure_foods.size() == Rules.ADVENTURES[level].food_count, "correct food count")
		check(game.adventure_pickups.values().has("shield") and game.adventure_pickups.values().has("bonus"), "both allowed pickups available")
		check(not game.adventure_pickups.values().has("shed"), "no Shed pickups")
		check(game.interval() < last_interval, "pace increases between mazes")
		last_interval = game.interval()
		var path := shortest_path(game)
		check(path.size() > last_shortest, "minimum exit route increases between mazes")
		last_shortest = path.size()
		for cell in game.snake:
			check(not game.walls.has(cell), "initial body clear")
		for cell in game.adventure_pickups:
			check(not game.walls.has(cell) and cell != game.exit_cell and not game.adventure_foods.has(cell), "pickup placement")
		for cell in path:
			game.queue_turn(cell - game.snake[0])
			game.tick_effects(game.interval())
			game.step()
		check(game.state == "adventure_clear", "shortest route is playable with growth")
		check(game.snake[0] == game.exit_cell, "finish requires exit")
		game.start("adventure", level)
		follow_route(game, routes[level])
		check(game.state == "adventure_clear", "full-food course is playable")
		check(game.eaten == Rules.ADVENTURES[level].food_count and game.adventure_foods.is_empty(), "all food collected on actual route")
		check(game.snake.size() == 4 + game.eaten, "no shrinking during course")
		check(game.finish_bonus == 1000 and game.length_bonus == game.eaten * 75, "finish and length scoring")
		check(game.time_bonus == 1000, "fast route earns full time bonus")
		check(Rules.adventure_medal_rank(level, game.score) == 3, "Gold attainable on real course")
		check(is_equal_approx(game.interval(), last_interval), "speed fixed within maze")
		var score: int = game.score
		var time: float = game.run_time
		game.step()
		game.tick_effects(100.0)
		check(game.score == score and game.run_time == time, "finish cannot be scored twice; clock stops")
		game.start("adventure", level)
		check(game.score == 0 and game.run_time == 0.0 and game.snake.size() == 4, "retry resets run")
		check(game.walls == start_walls and game.adventure_foods == start_food, "retry identical fair course")
		var targets: Array[int] = Rules.adventure_medal_targets(level)
		for rank in range(3):
			check(Rules.adventure_medal_rank(level, targets[rank] - 1) == rank, "below medal target")
			check(Rules.adventure_medal_rank(level, targets[rank]) == rank + 1, "exact medal target")
		game.state = "paused"
		game.tick_effects(500.0)
		check(game.run_time == 0.0, "pause excludes time")
		game.state = "shield_save"
		game.tick_effects(500.0)
		check(game.run_time == 0.0, "shield recovery excludes time")
		game.state = "playing"
		game.tick_effects(float(Rules.ADVENTURES[level].par) * 1.5)
		check(game.adventure_time_bonus() == 500, "time bonus declines after par")
		game.tick_effects(1000.0)
		check(game.adventure_time_bonus() == 0, "slow run time bonus floors at zero")
		game.adventure_foods.clear()
		game.adventure_pickups.clear()
		follow_route(game, routes[level])
		check(game.state == "adventure_clear" and game.score == 1000, "slow finish with no food still earns Bronze")
		check(game.snake.size() == 4, "no automatic shedding")
		game.start("adventure", level)
		game.spawn_power()
		check(game.pickup_kind == "", "no random Adventure powerup spawning")
		print("Maze %d: shortest %d moves, full-food route %d, Gold %d pts" % [level + 1, path.size(), routes[level].length(), score])
	# Persistence and menu flow, using only the disposable test profile.
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.set_process(false)
	ui.muted = true
	ui.best = 3340
	ui.cleared_count = 6
	ui.endless_bests.fill(0)
	ui.endless_bests[9] = 300
	ui.adventure_bests.fill(0)
	ui.adventure_times.fill(0.0)
	ui.select_mode("adventure")
	check(not ui.action_button.disabled and ui.arena_buttons[6].visible and not ui.arena_buttons[7].visible, "seven selectable mazes")
	ui.primary_action()
	ui.game.score = 9999
	ui.game.state = "game_over"
	ui.handle_event("crash")
	check(ui.adventure_bests[0] == 0 and ui.best == 3340, "death banks no Adventure record")
	ui.new_run()
	follow_route(ui.game, routes[0])
	ui.handle_event("adventure_clear")
	var recorded: int = ui.adventure_bests[0]
	var fastest: float = ui.adventure_times[0]
	check(recorded >= Rules.adventure_medal_targets(0)[2], "finish records Gold")
	check(ui.best == 3340 and ui.cleared_count == 6 and ui.endless_bests[9] == 300, "other mode progress preserved")
	ui.sync_buttons()
	check(ui.replay_button.visible and ui.action_button.text.begins_with("Next maze"), "completion offers next and replay")
	ui.new_run()
	check(ui.game.stage == 0 and ui.game.mode == "adventure", "R replays same maze")
	follow_route(ui.game, routes[0])
	ui.game.score = 1000
	ui.game.run_time = fastest + 100
	ui.handle_event("adventure_clear")
	check(ui.adventure_bests[0] == recorded and ui.adventure_times[0] == fastest, "lower result cannot downgrade records")
	ui.primary_action()
	check(ui.game.stage == 1 and ui.game.score == 0 and ui.game.run_time == 0, "next maze is independent run")
	ui.game.start("adventure", 6)
	follow_route(ui.game, routes[6])
	ui.handle_event("adventure_clear")
	ui.primary_action()
	check(ui.game.state == "title" and ui.menu_mode == "adventure" and ui.selected_stage == 6, "final maze returns to selection")
	ui.save_progress()
	var loaded = load("res://main.tscn").instantiate()
	root.add_child(loaded)
	loaded.set_process(false)
	check(loaded.adventure_bests == ui.adventure_bests and loaded.adventure_times == ui.adventure_times, "Adventure records persist")
	check(loaded.best == 3340 and loaded.cleared_count == 6 and loaded.endless_bests[9] == 300, "other records survive reload")
	ui.select_mode("endless")
	ui.select_arena(9)
	ui.select_mode("adventure")
	check(ui.selected_stage == 6 and ui.menu_preview.mode == "adventure", "switching modes clamps preview index")
	ui.select_mode("campaign")
	ui.primary_action()
	check(ui.game.mode == "campaign" and ui.game.stage == 0, "Campaign still starts normally")
	ui.free()
	loaded.free()
	await process_frame
	print("ADVENTURE CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)

