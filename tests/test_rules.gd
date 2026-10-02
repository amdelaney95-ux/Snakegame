extends SceneTree

const Rules = preload("res://scripts/snake_game.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _init() -> void:
	var game = Rules.new()
	game.start()
	check(game.snake.size() == 4 and game.state == "playing", "new run")
	game.food = Vector2i(23, 19)
	game.queue_turn(Vector2i.LEFT)
	check(game.turns.is_empty(), "immediate reverse is rejected")
	game.queue_turn(Vector2i.UP)
	game.queue_turn(Vector2i.LEFT)
	game.queue_turn(Vector2i.DOWN)
	check(game.turns.size() == 2, "two-turn input buffer")
	game.step()
	check(game.snake[0] == Vector2i(6, 9), "first buffered turn")
	game.step()
	check(game.snake[0] == Vector2i(5, 9), "second buffered turn")
	game.start()
	game.food = Vector2i(7, 10)
	check(game.step() == "food", "food event")
	check(game.score == 10 and game.snake.size() == 5 and game.eaten == 1, "growth and scoring")
	game.snake.assign([Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1)])
	game.direction = Vector2i.RIGHT
	game.food = Vector2i(23, 19)
	check(game.step() == "move", "moving into vacating tail is legal")
	game.snake.assign([Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(3, 1)])
	check(game.step() == "crash", "body collision")
	game.start()
	game.snake.assign([Vector2i(23, 10), Vector2i(22, 10)])
	game.shield = true
	check(game.step() == "shield" and game.state == "shield_save", "shield catches collision")
	check(game.snake[0] == Vector2i(23, 10) and not game.shield, "shield consumes without moving out of board")
	check(not game.resume_from_shield(Vector2i.RIGHT), "shield cannot resume into wall")
	check(not game.resume_from_shield(Vector2i.LEFT), "shield cannot reverse")
	check(game.resume_from_shield(Vector2i.UP), "shield resumes on safe turn")
	game.start()
	game.state = "paused"
	game.pickup_kind = "shed"
	game.pickup_time = 8.0
	game.tick_effects(2.0)
	check(game.pickup_time == 8.0 and game.step() == "", "pause freezes movement and pickup expiry")
	for kind in ["shield", "shed", "bonus"]:
		game.start()
		game.food = Vector2i(20, 19)
		game.pickup = Vector2i(7, 10)
		game.pickup_kind = kind
		check(game.step() == kind, "collect " + kind)
		check(game.pickup_kind == "", "remove collected " + kind)
		if kind == "shield": check(game.shield, "shield armed")
		if kind == "shed": check(game.snake.size() == 3 and game.last_shed_count == 1, "shed trims a short snake to minimum")
		if kind == "bonus": check(game.score == 50, "bonus score")
		check(is_equal_approx(game.interval(), 0.17), "pickup never changes movement speed: " + kind)
	# Test a longer, bent snake. Only the tail may disappear, even with buffered input.
	game.start()
	game.snake.assign([Vector2i(8, 10), Vector2i(7, 10), Vector2i(6, 10), Vector2i(5, 10), Vector2i(4, 10), Vector2i(3, 10), Vector2i(3, 11), Vector2i(3, 12), Vector2i(4, 12), Vector2i(5, 12)])
	game.food = Vector2i(23, 19)
	game.pickup = Vector2i(8, 9)
	game.pickup_kind = "shed"
	game.score = 120
	game.eaten = 2
	game.total_food = 2
	game.shield = true
	game.queue_turn(Vector2i.UP)
	game.queue_turn(Vector2i.RIGHT)
	check(game.step() == "shed" and game.snake.size() == 7 and game.last_shed_count == 3, "ten segments shed exactly thirty percent")
	check(game.snake[0] == Vector2i(8, 9) and game.snake.back() == Vector2i(3, 10), "shed preserves head and contiguous body")
	check(game.score == 120 and game.eaten == 2 and game.total_food == 2, "shed preserves score and progress")
	check(game.direction == Vector2i.UP and game.turns == [Vector2i.RIGHT] and game.shield, "shed preserves heading, queued turn and shield")
	game.tick_effects(20.0)
	check(is_equal_approx(game.interval(), 0.17) and game.snake.size() == 7, "shed never expires or changes speed later")
	game.step()
	check(game.snake[0] == Vector2i(9, 9), "buffered turn still executes after shedding")
	for length in [3, 4, 5, 7, 10, 11, 20]:
		game.start()
		game.snake.clear()
		for x in range(length):
			game.snake.append(Vector2i(20 - x, 10))
		game.food = Vector2i(23, 19)
		game.pickup = Vector2i(21, 10)
		game.pickup_kind = "shed"
		game.step()
		var expected := maxi(3, length - ceili(length * 0.30))
		check(game.snake.size() == expected, "percentage and minimum at length " + str(length))
		for repeat in range(6):
			game.pickup = game.snake[0] + Vector2i.UP
			game.pickup_kind = "shed"
			game.queue_turn(Vector2i.UP)
			game.step()
		check(game.snake.size() == 3 and game.state == "playing", "repeated shed stops at minimum")
	game.start()
	for kind in ["shield", "shed", "bonus", "shield"]:
		game.spawn_power()
		check(game.pickup_kind == kind, "updated pickup cycle: " + kind)
	for stage in range(Rules.STAGES.size()):
		game.stage = stage
		game.prepare_stage()
		var pace: float = game.interval()
		game.tick_effects(100.0)
		check(is_equal_approx(game.interval(), pace), "constant speed in stage " + str(stage))
	game.start()
	game.spawn_power()
	game.tick_effects(15.0)
	check(game.pickup_kind == "" and game.pickup == Vector2i(-1, -1), "power pickup expires")
	game.start()
	for stage in range(Rules.STAGES.size()):
		game.eaten = int(Rules.STAGES[stage].goal) - 1
		game.food = game.snake[0] + Vector2i.RIGHT
		var event: String = game.step()
		if stage < Rules.STAGES.size() - 1:
			check(event == "stage_clear", "stage clear " + str(stage))
			game.next_stage()
			check(game.stage == stage + 1 and game.snake.size() == 4 and game.eaten == 0, "next stage resets board")
		else:
			check(event == "victory", "ten-stage victory")
	check(game.score == 6050, "one food plus clear bonus on each of ten stages")
	check(Rules.STAGES.size() == 10, "exactly ten stages")
	var previous_wall_count := -1
	var previous_pace := 0.0
	for stage in range(Rules.STAGES.size()):
		game.stage = stage
		game.prepare_stage()
		check(game.walls.size() > previous_wall_count, "obstacle count increases stage " + str(stage))
		previous_wall_count = game.walls.size()
		if stage > 0:
			check(is_equal_approx(previous_pace / game.interval(), 1.05), "five percent faster stage " + str(stage))
		previous_pace = game.interval()
		for segment in game.snake:
			check(not game.walls.has(segment), "clear starting snake stage " + str(stage))
		for x in range(7, 13):
			check(not game.walls.has(Vector2i(x, 10)), "clear starting runway stage " + str(stage))
		check(not game.walls.has(game.food) and not game.snake.has(game.food), "safe food spawn stage " + str(stage))
		for wall in game.walls:
			check(wall.x >= 0 and wall.x < Rules.WIDTH and wall.y >= 0 and wall.y < Rules.HEIGHT, "wall stays inside board")
		for i in range(100):
			game.spawn_power()
			check(not game.snake.has(game.pickup) and not game.walls.has(game.pickup) and game.pickup != game.food, "safe spawn stage " + str(stage))
		# Flood fill verifies that obstacles do not create unreachable pockets.
		var visited: Array[Vector2i] = [game.snake[0]]
		var pending: Array[Vector2i] = [game.snake[0]]
		while not pending.is_empty():
			var cell: Vector2i = pending.pop_front()
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = cell + direction
				if next.x >= 0 and next.x < Rules.WIDTH and next.y >= 0 and next.y < Rules.HEIGHT and not game.walls.has(next) and not visited.has(next):
					visited.append(next)
					pending.append(next)
		check(visited.size() == Rules.WIDTH * Rules.HEIGHT - game.walls.size(), "all free cells reachable stage " + str(stage))
	print("RULE CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
