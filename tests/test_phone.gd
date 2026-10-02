extends SceneTree
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

func touch(point: Vector2, finger: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = ui.get_global_transform_with_canvas() * point
	event.index = finger
	event.pressed = true
	ui._input(event)

func run() -> void:
	root.size = Vector2i(390, 716)
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.set_process(false)
	ui.muted = true
	check(ui.phone_layout, "small viewport selects phone UI")
	ui.select_mode("adventure")
	ui.primary_action()
	check(ui.phone_ready and ui.game.state == "paused", "phone starts with inspectable ready screen")
	check(ui.action_button.text == "Go!", "ready screen has Go button")
	ui.game.tick_effects(50.0)
	check(ui.game.run_time == 0.0, "ready screen does not consume scored time")
	ui.primary_action()
	check(ui.game.state == "playing" and not ui.phone_ready, "Go starts run")
	ui.game.start()
	touch(ui.phone.direction_rects[Vector2i.UP].get_center())
	touch(ui.phone.direction_rects[Vector2i.LEFT].get_center(), 1)
	check(ui.game.turns == [Vector2i.UP, Vector2i.LEFT], "two different fingers can buffer two turns")
	ui.game.step()
	check(ui.game.direction == Vector2i.UP, "tap steers on next step")
	ui.game.step()
	check(ui.game.direction == Vector2i.LEFT, "second buffered tap follows")
	touch(ui.phone.direction_rects[Vector2i.RIGHT].get_center())
	check(ui.game.turns.is_empty(), "touch reversal rejected")
	ui.game.start()
	var start: Vector2 = ui.phone.board_rect.get_center()
	touch(start)
	var drag := InputEventScreenDrag.new()
	drag.position = ui.get_global_transform_with_canvas() * (start + Vector2(0, -30))
	drag.index = 0
	ui._input(drag)
	check(ui.game.turns == [Vector2i.UP], "swipe steers")
	drag.position = ui.get_global_transform_with_canvas() * (start + Vector2(-32, -30))
	ui._input(drag)
	check(ui.game.turns == [Vector2i.UP, Vector2i.LEFT], "continuous swipe can change direction")
	ui.pause_for_background()
	check(ui.game.state == "paused" and ui.phone.swipe_origins.is_empty(), "leaving app pauses and clears gestures")
	ui.game.turns.clear()
	touch(ui.phone.direction_rects[Vector2i.DOWN].get_center())
	check(ui.game.turns.is_empty(), "paused touch cannot queue movement")
	ui.game.start()
	ui.game.snake.assign([Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10)])
	ui.game.direction = Vector2i.LEFT
	ui.game.shield = true
	ui.handle_event(ui.game.step())
	touch(ui.phone.direction_rects[Vector2i.RIGHT].get_center())
	check(ui.game.state == "shield_save", "shield touch cannot reverse")
	touch(ui.phone.direction_rects[Vector2i.UP].get_center())
	check(ui.game.state == "playing" and ui.game.direction == Vector2i.UP, "safe touch resumes shield save")
	for dimensions in [Vector2(390, 550), Vector2(390, 620), Vector2(390, 820), Vector2(780, 390)]:
		ui.phone.configure(dimensions)
		for mode in ["campaign", "endless", "adventure"]:
			ui.show_menu()
			ui.select_mode(mode)
			ui.phone.arrange()
			var full := Rect2(Vector2.ZERO, dimensions)
			check(full.encloses(ui.action_button.get_rect()), "start fits viewport")
			check(full.encloses(ui.phone.card_bounds(6 if mode == "adventure" else 9)), "last course fits viewport")
			check(not ui.action_button.get_rect().intersects(ui.phone.card_bounds(6 if mode == "adventure" else 9)), "start does not overlap course selection")
		for r in ui.phone.direction_rects.values():
			check(Rect2(Vector2.ZERO, dimensions).encloses(r) and r.size.x >= 44 and r.size.y >= 44, "direction targets fit and are large enough")
		check(ui.phone.board_rect.size.y > 200 and Rect2(Vector2.ZERO, dimensions).encloses(ui.phone.board_rect), "board fits portrait and landscape")
	ui.free()
	await process_frame
	print("PHONE CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
