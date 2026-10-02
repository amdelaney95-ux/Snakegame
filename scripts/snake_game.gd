extends RefCounted
## Grid rules are kept separate from presentation, so stages and power-ups are easy to extend.

const Adventure = preload("res://scripts/adventure_levels.gd")
const ADVENTURES = Adventure.LEVELS
const WIDTH := 24
const HEIGHT := 20
const SHED_FRACTION := 0.30
const MIN_LENGTH := 3
const BASE_INTERVAL := 0.17
const STAGE_SPEED_MULTIPLIER := 1.05
# Wall rectangles use grid coordinates: x, y, width, height.
const STAGES := [
	{"name": "The Garden", "subtitle": "Find your rhythm.", "goal": 5, "walls": []},
	{"name": "Crossroads", "subtitle": "Mind the gaps.", "goal": 6, "walls": [
		[11, 3, 1, 5], [11, 12, 1, 5]]},
	{"name": "The Circuit", "subtitle": "Make every turn count.", "goal": 7, "walls": [
		[5, 5, 6, 1], [13, 5, 6, 1], [5, 14, 6, 1], [13, 14, 6, 1], [16, 8, 1, 4]]},
	{"name": "Switchback", "subtitle": "Read the road ahead.", "goal": 8, "walls": [
		[3, 4, 14, 1], [7, 8, 14, 1], [3, 14, 14, 1]]},
	{"name": "The Pillars", "subtitle": "Thread between the columns.", "goal": 9, "walls": [
		[5, 3, 2, 4], [11, 3, 2, 4], [17, 3, 2, 4],
		[5, 13, 2, 4], [11, 13, 2, 4], [17, 13, 2, 4]]},
	{"name": "The Weave", "subtitle": "Find a line through the hooks.", "goal": 10, "walls": [
		[7, 2, 1, 6], [7, 12, 1, 6], [12, 2, 1, 6], [12, 12, 1, 6], [17, 2, 1, 6], [17, 12, 1, 6],
		[8, 3, 3, 1], [13, 3, 3, 1], [18, 3, 3, 1], [8, 16, 3, 1], [13, 16, 3, 1], [18, 16, 3, 1]]},
	{"name": "The Gates", "subtitle": "Aim for the openings.", "goal": 11, "walls": [
		[2, 4, 4, 1], [8, 4, 8, 1], [18, 4, 4, 1],
		[2, 8, 7, 1], [11, 8, 2, 1], [15, 8, 7, 1],
		[2, 13, 4, 1], [8, 13, 8, 1], [18, 13, 4, 1],
		[2, 17, 7, 1], [11, 17, 2, 1], [15, 17, 7, 1]]},
	{"name": "The Foundry", "subtitle": "Stay light on your turns.", "goal": 12, "walls": [
		[4, 3, 3, 3], [17, 3, 3, 3], [4, 14, 3, 3], [17, 14, 3, 3],
		[8, 7, 8, 1], [8, 12, 8, 1], [15, 9, 2, 2], [8, 4, 7, 1], [8, 15, 7, 1]]},
	{"name": "Switchyard", "subtitle": "Plan your exit before you enter.", "goal": 13, "walls": [
		[7, 2, 2, 6], [7, 12, 2, 6], [12, 2, 2, 6], [12, 12, 2, 6], [17, 2, 2, 6], [17, 12, 2, 6],
		[3, 4, 2, 2], [20, 14, 2, 2]]},
	{"name": "The Gauntlet", "subtitle": "Bring it all together.", "goal": 14, "walls": [
		[2, 3, 3, 1], [8, 3, 14, 1], [2, 7, 14, 1], [19, 7, 3, 1],
		[2, 12, 6, 1], [11, 12, 11, 1], [2, 16, 13, 1], [18, 16, 4, 1],
		[4, 4, 1, 2], [19, 8, 1, 3], [4, 13, 1, 2], [1, 9, 2, 2], [21, 9, 2, 2]]},
]
var adventure_foods: Array[Vector2i] = []
var adventure_pickups: Dictionary = {}
var exit_cell := Vector2i(-1, -1)
var run_time := 0.0
var time_bonus := 0
var length_bonus := 0
var finish_bonus := 0
var rng := RandomNumberGenerator.new()
var state := "title"
var mode := "campaign"
var stage := 0
var score := 0
var eaten := 0
var total_food := 0
var snake: Array[Vector2i] = []
var walls: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var turns: Array[Vector2i] = []
var food := Vector2i(-1, -1)
var pickup := Vector2i(-1, -1)
var pickup_kind := ""
var pickup_time := 0.0
var last_shed_count := 0
var shield := false
var crash_reason := ""
var power_cycle := 0

func _init() -> void:
	rng.randomize()
	prepare_stage()
	state = "title"

func start(run_mode: String = "campaign", arena: int = 0) -> void:
	mode = run_mode if run_mode in ["endless", "adventure"] else "campaign"
	stage = clampi(arena, 0, (ADVENTURES.size() if mode == "adventure" else STAGES.size()) - 1) if mode != "campaign" else 0
	score = 0
	total_food = 0
	power_cycle = 0
	prepare_stage()

func prepare_stage() -> void:
	run_time = 0.0
	time_bonus = 0
	length_bonus = 0
	finish_bonus = 0
	exit_cell = Vector2i(-1, -1)
	adventure_foods.clear()
	adventure_pickups.clear()
	eaten = 0
	snake.assign([Vector2i(6, 10), Vector2i(5, 10), Vector2i(4, 10), Vector2i(3, 10)])
	direction = Vector2i.RIGHT
	turns.clear()
	walls.clear()
	shield = false
	last_shed_count = 0
	pickup = Vector2i(-1, -1)
	pickup_kind = ""
	pickup_time = 0.0
	crash_reason = ""
	if mode == "adventure":
		prepare_adventure()
		state = "playing"
		return
	for rect in STAGES[stage].walls:
		for y in range(rect[1], rect[1] + rect[3]):
			for x in range(rect[0], rect[0] + rect[2]):
				var cell := Vector2i(x, y)
				if not walls.has(cell):
					walls.append(cell)
	food = empty_cell()
	state = "playing"

func next_stage() -> void:
	if mode != "campaign" or state != "stage_clear":
		return
	stage += 1
	prepare_stage()

func queue_turn(value: Vector2i) -> void:
	if state != "playing" or turns.size() >= 2:
		return
	var previous: Vector2i = direction if turns.is_empty() else turns.back()
	if value != previous and value != -previous:
		turns.append(value)

func interval() -> float:
	return BASE_INTERVAL / pow(1.08 if mode == "adventure" else STAGE_SPEED_MULTIPLIER, stage)

func tick_effects(delta: float) -> void:
	if state != "playing":
		return
	if mode == "adventure":
		run_time += maxf(0.0, delta)
		return
	if pickup_kind != "":
		pickup_time -= delta
		if pickup_time <= 0.0:
			pickup_kind = ""
			pickup = Vector2i(-1, -1)

func step() -> String:
	if state != "playing":
		return ""
	if not turns.is_empty():
		direction = turns.pop_front()
	var next := snake[0] + direction
	var growing: bool = adventure_foods.has(next) if mode == "adventure" else next == food
	# The tail vacates its cell on a non-growing move.
	var occupied := snake.size() if growing else snake.size() - 1
	var hit_body := false
	for i in range(occupied):
		if snake[i] == next:
			hit_body = true
	var outside := next.x < 0 or next.x >= WIDTH or next.y < 0 or next.y >= HEIGHT
	if outside or walls.has(next) or hit_body:
		if shield:
			shield = false
			turns.clear()
			state = "shield_save"
			return "shield"
		crash_reason = "You hit the edge." if outside else ("You hit a wall." if walls.has(next) else "You crossed your tail.")
		state = "game_over"
		return "crash"
	snake.push_front(next)
	if not growing:
		snake.pop_back()
	var result := "move"
	if mode == "adventure":
		return adventure_step(next, growing)
	if next == pickup and pickup_kind != "":
		match pickup_kind:
			"shield": shield = true
			"shed":
				# Remove from the tail only, keeping the head, heading and score intact.
				last_shed_count = mini(ceili(snake.size() * SHED_FRACTION), maxi(0, snake.size() - MIN_LENGTH))
				snake.resize(snake.size() - last_shed_count)
			"bonus": score += 50
		result = pickup_kind
		pickup_kind = ""
		pickup = Vector2i(-1, -1)
	if growing:
		score += 10 * (stage + 1)
		eaten += 1
		total_food += 1
		result = "food"
		if mode == "campaign" and eaten >= int(STAGES[stage].goal):
			score += 100 * (stage + 1)
			state = "victory" if stage == STAGES.size() - 1 else "stage_clear"
			return state
		food = empty_cell()
		if food == Vector2i(-1, -1):
			# Free the final pickup cell before considering the board full.
			pickup_kind = ""
			pickup = Vector2i(-1, -1)
			food = empty_cell()
		if food == Vector2i(-1, -1) and mode == "endless":
			# A perfect full board automatically sheds tail so Endless can continue.
			last_shed_count = ceili(snake.size() * SHED_FRACTION)
			snake.resize(snake.size() - last_shed_count)
			food = empty_cell()
			result = "board_full"
		if eaten % 2 == 0 and pickup_kind == "":
			spawn_power()
	return result

static func medal_targets(arena: int) -> Array[int]:
	var value := 10 * (clampi(arena, 0, STAGES.size() - 1) + 1)
	return [15 * value, 35 * value, 65 * value]

static func medal_rank(arena: int, points: int) -> int:
	var rank := 0
	for target in medal_targets(arena):
		if points >= target:
			rank += 1
	return rank

func resume_from_shield(value: Vector2i) -> bool:
	# A shield stops time until the player chooses a safe direction.
	if state != "shield_save" or value == -direction:
		return false
	var cell := snake[0] + value
	if cell.x < 0 or cell.x >= WIDTH or cell.y < 0 or cell.y >= HEIGHT or walls.has(cell):
		return false
	for i in range(snake.size() - 1):
		if snake[i] == cell:
			return false
	direction = value
	state = "playing"
	return true

func spawn_power() -> void:
	if mode == "adventure":
		return # Adventure uses fixed, non-expiring Shield and Bonus pickups.
	pickup = empty_cell()
	if pickup == Vector2i(-1, -1):
		return
	pickup_kind = ["shield", "shed", "bonus"][power_cycle % 3]
	power_cycle += 1
	pickup_time = 14.0

func empty_cell() -> Vector2i:
	var cells: Array[Vector2i] = []
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := Vector2i(x, y)
			if not snake.has(cell) and not walls.has(cell) and cell != pickup and cell != food:
				cells.append(cell)
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[rng.randi_range(0, cells.size() - 1)]

func prepare_adventure() -> void:
	food = Vector2i(-1, -1)
	var layout: Array = ADVENTURES[stage].map
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := Vector2i(x, y)
			match layout[y][x]:
				"#": walls.append(cell)
				"S": snake.assign([cell, cell + Vector2i.LEFT, cell + Vector2i.LEFT * 2, cell + Vector2i.LEFT * 3])
				"E": exit_cell = cell
				"o": adventure_foods.append(cell)
				"s": adventure_pickups[cell] = "shield"
				"+": adventure_pickups[cell] = "bonus"

func adventure_step(next: Vector2i, growing: bool) -> String:
	var result := "move"
	if growing:
		adventure_foods.erase(next)
		eaten += 1
		total_food += 1
		score += 25
		result = "food"
	if adventure_pickups.has(next):
		result = adventure_pickups[next]
		if result == "shield":
			shield = true
		elif result == "bonus":
			score += 50
		adventure_pickups.erase(next)
	if next == exit_cell:
		finish_bonus = 1000
		time_bonus = adventure_time_bonus()
		length_bonus = maxi(0, snake.size() - 4) * 75
		score += finish_bonus + time_bonus + length_bonus
		state = "adventure_clear"
		return state
	return result

func adventure_time_bonus() -> int:
	# Full speed bonus at par; falls continuously to zero at twice par.
	return roundi(1000.0 * clampf(2.0 - run_time / float(ADVENTURES[stage].par), 0.0, 1.0))

static func adventure_medal_targets(level: int) -> Array[int]:
	return [1000, 2000, 1850 + int(ADVENTURES[clampi(level, 0, ADVENTURES.size() - 1)].food_count) * 100]

static func adventure_medal_rank(level: int, points: int) -> int:
	var rank := 0
	for target in adventure_medal_targets(level):
		if points >= target:
			rank += 1
	return rank
