extends "res://scripts/EngineeringWorkbench.gd"

const HISTORY_PATH := "user://engineering_analysis_history.json"
const INVENTORY_SLOTS := 32
const HAND_CARD_SIZE := Vector2(112, 148)

class MoveHandle extends Control:
	var target: Control
	var dragging := false
	var drag_offset := Vector2.ZERO

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging and target != null:
				drag_offset = get_global_mouse_position() - target.global_position
			accept_event()
		elif event is InputEventMouseMotion and dragging and target != null:
			target.global_position = get_global_mouse_position() - drag_offset
			accept_event()

class CardDropRow extends HBoxContainer:
	var host: Control

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		var allowed: bool = host != null and bool(host.call("can_drop_to_zone", "hand", data))
		self_modulate = Color("#b8e8c0") if allowed else Color("#e8b8b8")
		return allowed

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		self_modulate = Color.WHITE
		if host != null:
			host.call("drop_to_zone", "hand", data)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			self_modulate = Color.WHITE

class HandFan extends Control:
	const CARD_SIZE := Vector2(112, 148)
	var host: Control
	var hovered_uid := -1

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		var allowed: bool = host != null and bool(host.call("can_drop_to_zone", "hand", data))
		self_modulate = Color("#b8e8c0") if allowed else Color("#e8b8b8")
		return allowed

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		self_modulate = Color.WHITE
		if host != null:
			host.call("drop_to_zone", "hand", data)

	func set_hovered_card(uid: int, hovered: bool) -> void:
		if hovered:
			hovered_uid = uid
		elif hovered_uid == uid:
			hovered_uid = -1
		layout_cards(true)

	func on_drag_started() -> void:
		hovered_uid = -1
		layout_cards(true)

	func layout_cards(animated: bool = true) -> void:
		var visible_cards: Array[Control] = []
		for child in get_children():
			if child is Control and child.visible:
				visible_cards.append(child)
		var count: int = visible_cards.size()
		if count == 0:
			return
		var available_width: float = maxf(size.x, 720.0)
		var card_width: float = CARD_SIZE.x
		var card_height: float = CARD_SIZE.y
		var spacing: float = 0.0
		if count > 1:
			spacing = clampf((available_width - card_width) / float(count - 1), 58.0, card_width * 0.82)
		var total_width: float = card_width + spacing * float(count - 1)
		var start_x: float = (available_width - total_width) * 0.5
		var center: float = float(count - 1) * 0.5
		for index in range(count):
			var card := visible_cards[index]
			if card == null:
				continue
			var uid: int = int(card.get_meta("hand_uid", -1))
			var is_hovered: bool = uid == hovered_uid
			var offset_from_center: float = float(index) - center
			var target_position := Vector2(start_x + float(index) * spacing, 9.0 + absf(offset_from_center) * 2.2)
			if is_hovered:
				target_position.y -= 20.0
			elif hovered_uid != -1 and index < _index_for_uid(hovered_uid):
				target_position.x -= 10.0
			elif hovered_uid != -1 and index > _index_for_uid(hovered_uid):
				target_position.x += 10.0
			var target_rotation: float = offset_from_center * 0.035
			var target_scale := Vector2.ONE * (1.07 if is_hovered else 1.0)
			card.pivot_offset = Vector2(card_width * 0.5, card_height)
			card.z_index = 100 if is_hovered else index
			if animated:
				var tween := create_tween()
				tween.set_parallel(true)
				tween.set_trans(Tween.TRANS_CUBIC)
				tween.set_ease(Tween.EASE_OUT)
				tween.tween_property(card, "position", target_position, 0.18)
				tween.tween_property(card, "rotation", target_rotation, 0.18)
				tween.tween_property(card, "scale", target_scale, 0.18)
			else:
				card.position = target_position
				card.rotation = target_rotation
				card.scale = target_scale

	func _index_for_uid(uid: int) -> int:
		var visible_index := 0
		for child in get_children():
			var card := child as Control
			if card == null or not card.visible:
				continue
			if int(card.get_meta("hand_uid", -1)) == uid:
				return visible_index
			visible_index += 1
		return -1

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			self_modulate = Color.WHITE

class FullDragCard extends PanelContainer:
	var host: Control
	var payload: Dictionary
	var title_text := ""
	var subtitle_text := ""
	var symbol_text := "◆"
	var card_size := Vector2(112, 132)

	func _ready() -> void:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

	func _on_mouse_entered() -> void:
		if host != null and str(payload.get("origin", "")) == "hand":
			host.call("_set_hand_card_hover", int(payload.get("uid", -1)), true)

	func _on_mouse_exited() -> void:
		if host != null and str(payload.get("origin", "")) == "hand":
			host.call("_set_hand_card_hover", int(payload.get("uid", -1)), false)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if host != null:
			set_drag_preview(host.call("_make_drag_preview", title_text, subtitle_text, symbol_text, card_size, payload))
		if str(payload.get("origin", "")) == "hand":
			hide()
			if host != null:
				host.call("_on_hand_card_drag_started", int(payload.get("uid", -1)))
		return payload

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		var allowed: bool = host != null and bool(host.call("can_drop_to_card", payload, data))
		self_modulate = Color("#b8e8c0") if allowed else Color("#e8b8b8")
		return allowed

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		self_modulate = Color.WHITE
		if host != null:
			host.call("drop_to_card", payload, data)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			self_modulate = Color.WHITE
			show()
			if host != null and str(payload.get("origin", "")) == "hand":
				host.call("_on_hand_card_drag_ended", int(payload.get("uid", -1)))


class InventoryDropWindow extends PanelContainer:
	var host: Control

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		var allowed: bool = host != null and bool(host.call("can_drop_to_zone", "inventory", data))
		self_modulate = Color("#b8e8c0") if allowed else Color("#e8b8b8")
		return allowed

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		self_modulate = Color.WHITE
		if host != null:
			host.call("drop_to_zone", "inventory", data)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			self_modulate = Color.WHITE

class CardArtwork extends Control:
	var item_id := ""
	var item_kind := ""

	func _draw() -> void:
		var rows: Array[String] = []
		match item_id:
			"iron", "copper":
				rows = [".#####.", "#######", "#######", ".#####.", "..###.."]
			"coal":
				rows = ["..###..", ".#####.", "#######", "#######", ".#####."]
			"heated_iron", "heated_copper":
				rows = ["...#...", "..###..", ".#####.", "..###..", ".#.#.#.", "......."]
			"iron_blank", "copper_blank":
				rows = ["#######", "#######", "#######", "#######"]
			"horseshoe":
				rows = ["##...##", "##...##", "##...##", "##...##", ".#####.", "..###.."]
			"copper_plate":
				rows = ["#######", "#.....#", "#.###.#", "#.....#", "#######"]
			_:
				if item_kind == "action":
					match item_id:
						"heat":
							rows = ["...#...", "..###..", ".#####.", "..###..", ".#.#.#."]
						"forge":
							rows = ["##.....", ".##....", "..##...", "#######", "...##..", "...##.."]
						"bend":
							rows = ["##.....", ".##....", "..##...", "...##..", "....##.", ".....##"]
		if rows.is_empty():
			rows = ["...#...", "..###..", ".#####.", "..###..", "...#..."]
		var pixel := 8.0
		var width := 7.0 * pixel
		var height := float(rows.size()) * pixel
		var origin := Vector2((size.x - width) * 0.5, (size.y - height) * 0.5)
		for y in range(rows.size()):
			for x in range(rows[y].length()):
				if rows[y][x] == "#":
					draw_rect(Rect2(origin + Vector2(x * pixel, y * pixel), Vector2(pixel, pixel)), Color("#f4f0df"))

var inventory_window: InventoryDropWindow
var inventory_grid: GridContainer
var drawer: PanelContainer
var drawer_content: VBoxContainer
var drawer_title: Label
var drawer_mode := "order"
var history: Array[Dictionary] = []
var history_list: VBoxContainer
var blueprint_detail: Label
var blueprint_selected := ""
var drawer_buttons: Dictionary = {}
var hand_count_label: Label


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := PanelContainer.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_theme_stylebox_override("panel", _style(Color("#080808"), Color("#f4f0df"), 2))
	add_child(backdrop)

	var margins := MarginContainer.new()
	for pair in [["margin_left", 12], ["margin_right", 12], ["margin_top", 8], ["margin_bottom", 8]]:
		margins.add_theme_constant_override(pair[0], pair[1])
	backdrop.add_child(margins)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	margins.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var heading := _label("КУЗНИЦА  /  ИНЖЕНЕРНАЯ МАСТЕРСКАЯ", 14, Color("#f4f0df"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_stretch_ratio = 1.0
	header.add_child(heading)
	for entry in [["Заказ", "order"], ["Анализ", "analysis"], ["Чертежи", "blueprints"], ["Инвентарь", "inventory"]]:
		var button := _button(entry[0], 32)
		button.pressed.connect(_on_top_button_pressed.bind(entry[1]))
		header.add_child(button)
		if entry[1] == "order":
			drawer_buttons.order = button
		elif entry[1] == "analysis":
			drawer_buttons.analysis = button
		elif entry[1] == "blueprints":
			drawer_buttons.blueprints = button

	var work_panel := PanelContainer.new()
	work_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work_panel.add_theme_stylebox_override("panel", _style(Color("#080808"), Color("#f4f0df"), 1))
	root.add_child(work_panel)
	var work_margin := MarginContainer.new()
	for pair in [["margin_left", 10], ["margin_right", 10], ["margin_top", 8], ["margin_bottom", 8]]:
		work_margin.add_theme_constant_override(pair[0], pair[1])
	work_panel.add_child(work_margin)
	var work_body := VBoxContainer.new()
	work_body.add_theme_constant_override("separation", 5)
	work_margin.add_child(work_body)
	work_body.add_child(_label("ИНЖЕНЕРНАЯ СХЕМА", 13, Color("#f4f0df")))
	graph_hint = _label("Перетащи карты из руки на поле. Соединяй выход одного узла со входом следующего.", 10, Color("#f4f0df"))
	graph_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	work_body.add_child(graph_hint)
	graph = GraphCanvas.new()
	graph.host = self
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.minimap_enabled = false
	graph.show_grid = true
	graph.grid_pattern = GraphEdit.GRID_PATTERN_DOTS
	graph.add_valid_connection_type(0, 0)
	graph.add_valid_left_disconnect_type(0)
	graph.add_valid_right_disconnect_type(0)
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	work_body.add_child(graph)

	var graph_buttons := HBoxContainer.new()
	work_body.add_child(graph_buttons)
	var run_button := _button("Проверить и выполнить схему", 36)
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_button.pressed.connect(_on_run_graph_pressed)
	graph_buttons.add_child(run_button)
	var clear_button := _button("Очистить схему", 36)
	clear_button.pressed.connect(_clear_graph)
	graph_buttons.add_child(clear_button)

	report_label = _label("", 10, Color("#f4f0df"))
	report_label.visible = false
	status_label = _label("Перетащи ресурсы и карты действий из инвентаря в руку.", 10, Color("#f4f0df"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	hand_zone = DropZone.new()
	hand_zone.host = self
	hand_zone.zone_kind = "hand"
	hand_zone.custom_minimum_size.y = 184
	hand_zone.add_theme_stylebox_override("panel", _style(Color("#080808"), Color("#f4f0df"), 1))
	root.add_child(hand_zone)
	var hand_margin := MarginContainer.new()
	for pair in [["margin_left", 8], ["margin_right", 8], ["margin_top", 6], ["margin_bottom", 6]]:
		hand_margin.add_theme_constant_override(pair[0], pair[1])
	hand_zone.add_child(hand_margin)
	var hand_body := VBoxContainer.new()
	hand_body.add_theme_constant_override("separation", 4)
	hand_margin.add_child(hand_body)
	var hand_header := HBoxContainer.new()
	hand_body.add_child(hand_header)
	hand_header.add_child(_label("РУКА", 11, Color("#f4f0df")))
	hand_count_label = _label("", 9, Color("#f4f0df"))
	hand_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand_header.add_child(hand_count_label)
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	hand_body.add_child(hand_row)
	discard_zone = DropZone.new()
	discard_zone.host = self
	discard_zone.zone_kind = "discard"
	discard_zone.custom_minimum_size = Vector2(95, 30)
	discard_zone.add_theme_stylebox_override("panel", _style(Color("#080808"), Color("#f4f0df"), 1))
	var discard_label := _label("СБРОСИТЬ", 9, Color("#f4f0df"))
	discard_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_zone.add_child(discard_label)
	hand_row.add_child(discard_zone)
	hand_list = HandFan.new()
	hand_list.host = self
	hand_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_list.custom_minimum_size.y = 156
	hand_list.clip_contents = false
	hand_row.add_child(hand_list)

	_build_inventory_window()
	_build_drawer()
	_load_history()
	_refresh_drawer()


func _build_inventory_window() -> void:
	inventory_window = InventoryDropWindow.new()
	inventory_window.host = self
	inventory_window.position = Vector2(24, 76)
	inventory_window.custom_minimum_size = Vector2(510, 560)
	inventory_window.size = Vector2(510, 560)
	inventory_window.z_index = 10
	inventory_window.add_theme_stylebox_override("panel", _style(Color("#080808"), Color("#f4f0df"), 2))
	add_child(inventory_window)
	inventory_window.hide()

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	inventory_window.add_child(body)
	var drag_bar := MoveHandle.new()
	drag_bar.custom_minimum_size.y = 28
	drag_bar.target = inventory_window
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_bar.add_theme_stylebox_override("panel", _style(Color("#080808"), Color("#f4f0df"), 1))
	body.add_child(drag_bar)
	var title := _label("⠿  КОЛОДА · ИНВЕНТАРЬ", 12, Color("#f4f0df"))
	title.position = Vector2(8, 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_bar.add_child(title)
	var inventory_close := Button.new()
	inventory_close.text = "×"
	inventory_close.position = Vector2(478, 1)
	inventory_close.size = Vector2(28, 26)
	inventory_close.z_index = 2
	inventory_close.tooltip_text = "Закрыть инвентарь"
	inventory_close.pressed.connect(func(): inventory_window.hide())
	drag_bar.add_child(inventory_close)
	var grid_margin := MarginContainer.new()
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for pair in [["margin_left", 7], ["margin_right", 7], ["margin_top", 4], ["margin_bottom", 7]]:
		grid_margin.add_theme_constant_override(pair[0], pair[1])
	body.add_child(grid_margin)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_margin.add_child(inventory_scroll)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 4
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 8)
	inventory_scroll.add_child(inventory_grid)


func _build_drawer() -> void:
	drawer = PanelContainer.new()
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_top = 0.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -370
	drawer.offset_right = -8
	drawer.offset_top = 52
	drawer.offset_bottom = -170
	drawer.z_index = 20
	drawer.visible = false
	drawer.add_theme_stylebox_override("panel", _style(Color("#080808"), Color("#f4f0df"), 2))
	add_child(drawer)
	var margin := MarginContainer.new()
	for pair in [["margin_left", 12], ["margin_right", 12], ["margin_top", 10], ["margin_bottom", 10]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	drawer.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	drawer_title = _label("АКТИВНЫЙ ЗАКАЗ", 14, Color("#f4f0df"))
	drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(drawer_title)
	var close_button := _button("×", 28)
	close_button.pressed.connect(func(): drawer.hide())
	header.add_child(close_button)
	drawer_content = VBoxContainer.new()
	drawer_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(drawer_content)


func _on_top_button_pressed(mode: String) -> void:
	if mode == "inventory":
		inventory_window.visible = not inventory_window.visible
		return
	if drawer.visible and drawer_mode == mode:
		drawer.hide()
		return
	drawer_mode = mode
	drawer.show()
	_refresh_drawer()


func _refresh_drawer() -> void:
	if drawer_content == null:
		return
	for child in drawer_content.get_children():
		child.queue_free()
	if drawer_mode == "order":
		drawer_title.text = "АКТИВНЫЙ ЗАКАЗ"
		_add_order_content()
	elif drawer_mode == "analysis":
		drawer_title.text = "АНАЛИЗ · ИСТОРИЯ"
		_add_analysis_content()
	elif drawer_mode == "blueprints":
		drawer_title.text = "ЧЕРТЕЖИ"
		_add_blueprints_content()


func _add_order_content() -> void:
	if current_order == null:
		drawer_content.add_child(_label("Сейчас нет активного заказа.", 11, Color("#f4f0df")))
		return
	var item_id := current_order.item_id
	drawer_content.add_child(_label("Заказчик: %s" % current_order.client_name, 12, Color("#f4f0df")))
	drawer_content.add_child(_label("Изделие: %s" % MATERIALS.get(item_id, {}).get("name", item_id), 11, Color("#f4f0df")))
	drawer_content.add_child(_label("Требуемое качество: %d/100" % current_order.required_quality, 10, Color("#f4f0df")))
	drawer_content.add_child(_label("Награда: %d монет" % current_order.reward_money, 10, Color("#f4f0df")))
	var description := _label(current_order.description, 10, Color("#f4f0df"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer_content.add_child(description)
	var quality := int(item_qualities.get(item_id, 0))
	drawer_content.add_child(_label("В инвентаре: %d · качество: %d" % [int(inventory.get(item_id, 0)), quality], 10, Color("#f4f0df")))
	var deliver := _button("Сдать изделие", 36)
	deliver.disabled = int(inventory.get(item_id, 0)) <= 0
	deliver.pressed.connect(_on_delivery_pressed)
	drawer_content.add_child(deliver)


func _add_analysis_content() -> void:
	var intro := _label("Отчёт появляется после сдачи заказа. Записи сохраняются между запусками игры.", 10, Color("#f4f0df"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer_content.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_content.add_child(scroll)
	history_list = VBoxContainer.new()
	history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_list.add_theme_constant_override("separation", 5)
	scroll.add_child(history_list)
	if history.is_empty():
		history_list.add_child(_label("История пока пуста.", 10, Color("#f4f0df")))
		return
	for index in range(history.size() - 1, -1, -1):
		var record: Dictionary = history[index]
		var row := _button("%s  ·  %s" % [str(record.get("date_time", "")), str(record.get("item_name", ""))], 42)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(_show_history_record.bind(index))
		history_list.add_child(row)


func _show_history_record(index: int) -> void:
	if index < 0 or index >= history.size():
		return
	var record: Dictionary = history[index]
	for child in drawer_content.get_children():
		child.queue_free()
	drawer_title.text = "ОТЧЁТ · %s" % str(record.get("item_name", "Заказ"))
	var back := _button("← К истории", 30)
	back.pressed.connect(_refresh_drawer)
	drawer_content.add_child(back)
	for line in [
		"Дата и время: %s" % str(record.get("date_time", "")),
		"Заказчик: %s" % str(record.get("client_name", "")),
		"Изделие: %s" % str(record.get("item_name", "")),
		"Качество: %s/100" % str(record.get("quality", 0)),
		"Требовалось: %s/100" % str(record.get("required_quality", 0)),
		"Операций: %s" % str(record.get("operations", 0)),
		"Расход угля: %s" % str(record.get("coal_used", 0)),
		"Цепочка: %s" % ", ".join(PackedStringArray(record.get("recipe_chain", []))),
		"Результат: %s" % str(record.get("result", "Заказ сдан"))
	]:
		var label := _label(line, 10, Color("#f4f0df"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		drawer_content.add_child(label)


func _add_blueprints_content() -> void:
	var note := _label("Тестовая справка: выбери чертёж, чтобы увидеть необходимые материалы и операции.", 10, Color("#f4f0df"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer_content.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 145
	drawer_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for recipe_id in RECIPES.keys():
		var recipe: Dictionary = RECIPES[recipe_id]
		var output_id := str(recipe.get("output", ""))
		var output_name := str(MATERIALS.get(output_id, {}).get("name", output_id))
		var button := _button(output_name, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_blueprint.bind(str(recipe_id)))
		list.add_child(button)
	blueprint_detail = _label("Выбери чертёж из списка.", 11, Color("#f4f0df"))
	blueprint_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer_content.add_child(blueprint_detail)
	if blueprint_selected != "":
		_select_blueprint(blueprint_selected)


func _select_blueprint(recipe_id: String) -> void:
	blueprint_selected = recipe_id
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	if recipe.is_empty() or blueprint_detail == null:
		return
	var input_id := str(recipe.get("input", ""))
	var output_id := str(recipe.get("output", ""))
	var action_names := PackedStringArray()
	for action_id in recipe.get("actions", []):
		action_names.append(str(ACTIONS.get(str(action_id), {}).get("name", action_id)))
	blueprint_detail.text = "Вход: %s\nОперация: %s\nВыход: %s\nУголь: %d" % [
		MATERIALS.get(input_id, {}).get("name", input_id),
		" → ".join(action_names),
		MATERIALS.get(output_id, {}).get("name", output_id),
		int(recipe.get("coal_cost", 0))
	]



func _style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(0)
	return box

func _make_drag_preview(title: String, subtitle: String, symbol: String, preview_size: Vector2, payload: Dictionary) -> Control:
	return _make_visual_card(payload, title, subtitle, symbol, Color("#f4f0df"), preview_size)


func _make_visual_card(payload: Dictionary, title: String, subtitle: String, symbol: String, tint: Color, card_size: Vector2) -> FullDragCard:
	var card := FullDragCard.new()
	card.host = self
	card.payload = payload.duplicate(true)
	card.title_text = title
	card.subtitle_text = subtitle
	card.symbol_text = symbol
	card.card_size = card_size
	card.custom_minimum_size = card_size
	card.size = card_size
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#080808")
	frame.border_color = Color("#f4f0df")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(0)
	card.add_theme_stylebox_override("panel", frame)

	var outer := MarginContainer.new()
	for pair in [["margin_left", 5], ["margin_right", 5], ["margin_top", 5], ["margin_bottom", 5]]:
		outer.add_theme_constant_override(pair[0], pair[1])
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(outer)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 3)
	outer.add_child(body)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(header)
	var kind := str(payload.get("kind", "resource"))
	var category := "ОПЕРАЦИЯ" if kind == "action" else ("ТОПЛИВО" if str(payload.get("id", "")) == "coal" else "МАТЕРИАЛ")
	var type_label := _label(category, 7, Color("#f4f0df"))
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(type_label)
	var count := int(payload.get("count", 0))
	if count > 0:
		var count_label := _label("×%d" % count, 9, Color("#f4f0df"))
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(count_label)

	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size.y = 62
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color("#080808")
	art_style.border_color = Color("#f4f0df")
	art_style.set_border_width_all(1)
	art_style.set_corner_radius_all(0)
	art_frame.add_theme_stylebox_override("panel", art_style)
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := CardArtwork.new()
	art.item_id = str(payload.get("id", ""))
	art.item_kind = kind
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art)
	body.add_child(art_frame)

	var name_label := _label(title, 10, Color("#f4f0df"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.y = 25
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(name_label)

	var detail_label := _label(subtitle, 8, Color("#f4f0df"))
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size.y = 22
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(detail_label)

	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(footer)
	var is_coal := str(payload.get("id", "")) == "coal"
	var stat_name := "МНОГОРАЗОВАЯ" if kind == "action" else ("ГОРЕНИЕ" if is_coal else "КАЧЕСТВО")
	var stat_value := "АКТИВНАЯ" if kind == "action" else ("ТОПЛИВО" if is_coal else "%d/100" % int(payload.get("quality", 0)))
	var stat_label := _label(stat_name, 7, Color("#f4f0df"))
	stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(stat_label)
	var value_label := _label(stat_value, 8, Color("#f4f0df"))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(value_label)
	return card

func _refresh_inventory() -> void:
	if inventory_grid == null:
		return
	for child in inventory_grid.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = []
	for item_id in MATERIALS.keys():
		var count := int(inventory.get(item_id, 0))
		if count > 0:
			entries.append({"kind": "resource", "id": str(item_id), "count": count})
	for action_id in ACTIONS.keys():
		if unlocked_actions.has(action_id) and int(action_inventory.get(action_id, 0)) > 0:
			entries.append({"kind": "action", "id": str(action_id), "count": int(action_inventory[action_id])})
	for slot in range(INVENTORY_SLOTS):
		if slot < entries.size():
			var entry: Dictionary = entries[slot]
			var id := str(entry.id)
			if str(entry.kind) == "resource":
				var data: Dictionary = MATERIALS.get(id, {})
				var quality := int(item_qualities.get(id, data.get("quality", 0)))
				var payload := {"origin": "inventory", "kind": "resource", "id": id, "quality": quality, "count": int(entry.count)}
				inventory_grid.add_child(_make_visual_card(payload, str(data.get("name", id)), str(data.get("kind", "Материал")).to_upper(), "◆", Color("#f4f0df"), HAND_CARD_SIZE))
			else:
				var action_data: Dictionary = ACTIONS.get(id, {})
				var payload := {"origin": "inventory", "kind": "action", "id": id, "count": int(entry.count)}
				inventory_grid.add_child(_make_visual_card(payload, str(action_data.get("name", id)), str(action_data.get("description", "Инженерная операция")), str(action_data.get("symbol", "⚒")), Color("#f4f0df"), HAND_CARD_SIZE))
		else:
			var empty := PanelContainer.new()
			empty.custom_minimum_size = HAND_CARD_SIZE
			empty.add_theme_stylebox_override("panel", _style(Color("#080808"), Color("#f4f0df"), 1))
			inventory_grid.add_child(empty)


func _refresh_hand() -> void:
	if hand_list == null:
		return
	for child in hand_list.get_children():
		child.queue_free()
	for data in hand_cards:
		var id := str(data.get("id", ""))
		var uid := int(data.get("uid", -1))
		if str(data.get("kind", "")) == "resource":
			var material: Dictionary = MATERIALS.get(id, {})
			var quality := int(data.get("quality", 0))
			var payload := {"origin": "hand", "kind": "resource", "id": id, "uid": uid}
			var card := _make_visual_card(payload, str(material.get("name", id)), "Материал / качество %d" % quality, "◆", Color("#f4f0df"), HAND_CARD_SIZE)
			card.set_meta("hand_uid", uid)
			hand_list.add_child(card)
		else:
			var action: Dictionary = ACTIONS.get(id, {})
			var payload := {"origin": "hand", "kind": "action", "id": id, "uid": uid}
			var card := _make_visual_card(payload, str(action.get("name", id)), str(action.get("description", "Многоразовая операция")), str(action.get("symbol", "⚒")), Color("#f4f0df"), HAND_CARD_SIZE)
			card.set_meta("hand_uid", uid)
			hand_list.add_child(card)
	if hand_count_label != null:
		hand_count_label.text = "%d карт" % hand_cards.size()
	hand_list.call_deferred("layout_cards", false)


func _set_hand_card_hover(uid: int, hovered: bool) -> void:
	if hand_list != null:
		hand_list.call("set_hovered_card", uid, hovered)

func _on_hand_card_drag_started(_uid: int) -> void:
	if hand_list != null:
		hand_list.call("on_drag_started")

func _on_hand_card_drag_ended(_uid: int) -> void:
	if hand_list != null:
		hand_list.call("layout_cards", true)

func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_hand()
	_refresh_order()
	if drawer != null and drawer.visible:
		_refresh_drawer()


func _refresh_order() -> void:
	if drawer != null and drawer.visible and drawer_mode == "order":
		_refresh_drawer()


func _on_blueprint_pressed() -> void:
	_on_top_button_pressed("blueprints")


func _on_delivery_pressed() -> void:
	if current_order == null:
		return
	var item_id := current_order.item_id
	if int(inventory.get(item_id, 0)) <= 0:
		return
	var quality := int(item_qualities.get(item_id, 0))
	var total_coal := 0
	var total_operations := 0
	var complete_chain := PackedStringArray()
	for process_step in order_process_history:
		total_coal += int(process_step.get("coal_used", 0))
		total_operations += int(process_step.get("operations", 0))
		for recipe_id in process_step.get("recipe_chain", []):
			complete_chain.append(str(recipe_id))
	if order_process_history.is_empty():
		total_coal = last_coal_used
		total_operations = last_action_count
		for recipe_id in last_recipe_chain:
			complete_chain.append(recipe_id)
	var record := {
		"date_time": Time.get_datetime_string_from_system(),
		"client_name": current_order.client_name,
		"item_id": item_id,
		"item_name": str(MATERIALS.get(item_id, {}).get("name", item_id)),
		"quality": quality,
		"required_quality": current_order.required_quality,
		"coal_used": total_coal,
		"operations": total_operations,
		"recipe_chain": Array(complete_chain),
		"process_steps": order_process_history.duplicate(true),
		"result": "Заказ выполнен" if quality >= current_order.required_quality else "Качество ниже требования"
	}
	history.append(record)
	_save_history()
	super._on_delivery_pressed()
	if drawer != null and drawer.visible and drawer_mode == "analysis":
		_refresh_drawer()


func _load_history() -> void:
	if not FileAccess.file_exists(HISTORY_PATH):
		return
	var file := FileAccess.open(HISTORY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		history.clear()
		for entry in parsed:
			if entry is Dictionary:
				history.append(entry)


func _save_history() -> void:
	var file := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(history, "\t"))


func set_order(order: Order) -> void:
	var order_changed := current_order != order
	super.set_order(order)
	if order_changed:
		order_process_history.clear()
	if drawer != null and drawer.visible and drawer_mode == "order":
		_refresh_drawer()
