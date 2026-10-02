extends SceneTree
## Follow real food spawns through the whole campaign without teleporting or changing scores.
const Rules = preload("res://scripts/snake_game.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

func path_to(game, target: Vector2i) -> Array[Vector2i]:
	var start: Vector2i = game.snake[0]
	var queue: Array[Vector2i] = [start]
	var previous := {start: start}
	var blocked := {}
	for wall in game.walls:
		blocked[wall] = true
	for i in range(game.snake.size() - 1):
		blocked[game.snake[i]] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == target:
			var result: Array[Vector2i] = []
			while cell != start:
				result.push_front(cell)
				cell = previous[cell]
			return result
		for direction in DIRECTIONS:
			if cell == start and direction == -game.direction:
				continue
			var next: Vector2i = cell + direction
			if next.x >= 0 and next.x < Rules.WIDTH and next.y >= 0 and next.y < Rules.HEIGHT and not blocked.has(next) and not previous.has(next):
				previous[next] = cell
				queue.append(next)
	return []

func _init() -> void:
	var game = Rules.new()
	game.rng.seed = 2701
	game.start()
	var moves := 0
	var stages_cleared := 0
	while moves < 10000 and game.state == "playing":
		var path := path_to(game, game.food)
		if path.is_empty():
			path = path_to(game, game.snake.back())
		if path.is_empty():
			push_error("Autoplay could not find a route in stage " + str(game.stage + 1))
			quit(1)
			return
		game.queue_turn(path[0] - game.snake[0])
		game.tick_effects(game.interval())
		game.step()
		moves += 1
		if game.state == "stage_clear":
			stages_cleared += 1
			print("Cleared stage %d: score %d, food %d" % [stages_cleared, game.score, game.total_food])
			game.next_stage()
	if game.state != "victory" or game.total_food != 95 or stages_cleared != 9:
		push_error("Campaign incomplete: %s, food %d, stage %d" % [game.state, game.total_food, game.stage + 1])
		quit(1)
		return
	print("CAMPAIGN PASS: 10 stages, 95 food, %d moves, %d points" % [moves, game.score])
	quit(0)
