extends "res://scripts/EngineeringWorkbench.gd"

const HISTORY_PATH := "user://engineering_analysis_history.json"
const INVENTORY_SLOTS := 32
const HAND_CARD_SIZE := Vector2(112, 132)

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

class FullDragCard extends PanelContainer:
	var host: Control
	var payload: Dictionary
	var title_text := ""
	var subtitle_text := ""
	var symbol_text := "◆"

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if host != null:
			set_drag_preview(host.call("_make_drag_preview", title_text, subtitle_text, symbol_text))
		return payload

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return host != null and host.call("can_drop_to_card", payload, data)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if host != null:
			host.call("drop_to_card", payload, data)

var inventory_window: PanelContainer
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
	backdrop.add_theme_stylebox_override("panel", _style(Color("#17130f"), Color("#a77b45"), 2))
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
	var heading := _label("КУЗНИЦА  /  ИНЖЕНЕРНАЯ МАСТЕРСКАЯ", 17, Color("#f0d6a5"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	work_panel.add_theme_stylebox_override("panel", _style(Color("#211a15"), Color("#725638"), 1))
	root.add_child(work_panel)
	var work_margin := MarginContainer.new()
	for pair in [["margin_left", 10], ["margin_right", 10], ["margin_top", 8], ["margin_bottom", 8]]:
		work_margin.add_theme_constant_override(pair[0], pair[1])
	work_panel.add_child(work_margin)
	var work_body := VBoxContainer.new()
	work_body.add_theme_constant_override("separation", 5)
	work_margin.add_child(work_body)
	work_body.add_child(_label("ИНЖЕНЕРНАЯ СХЕМА", 13, Color("#c99b60")))
	graph_hint = _label("Перетащи карты из руки на поле. Соединяй выход одного узла со входом следующего.", 10, Color("#b8a58d"))
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

	status_label = _label("Перетащи ресурсы и карты действий из инвентаря в руку.", 10, Color("#e7c78d"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	hand_zone = DropZone.new()
	hand_zone.host = self
	hand_zone.zone_kind = "hand"
	hand_zone.custom_minimum_size.y = 150
	hand_zone.add_theme_stylebox_override("panel", _style(Color("#302219"), Color("#987044"), 1))
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
	hand_header.add_child(_label("РУКА · 8 СЛОТОВ", 11, Color("#c99b60")))
	hand_count_label = _label("", 9, Color("#b8a58d"))
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
	discard_zone.add_theme_stylebox_override("panel", _style(Color("#482321"), Color("#a45b4f"), 1))
	var discard_label := _label("СБРОСИТЬ", 9, Color("#e2b0a0"))
	discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_zone.add_child(discard_label)
	hand_row.add_child(discard_zone)
	hand_list = HBoxContainer.new()
	hand_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_list.add_theme_constant_override("separation", 6)
	hand_row.add_child(hand_list)

	_build_inventory_window()
	_build_drawer()
	_load_history()
	_refresh_drawer()


func _build_inventory_window() -> void:
	inventory_window = PanelContainer.new()
	inventory_window.position = Vector2(24, 76)
	inventory_window.custom_minimum_size = Vector2(330, 300)
	inventory_window.size = Vector2(330, 300)
	inventory_window.z_index = 10
	inventory_window.add_theme_stylebox_override("panel", _style(Color("#292019"), Color("#c09258"), 2))
	add_child(inventory_window)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	inventory_window.add_child(body)
	var drag_bar := MoveHandle.new()
	drag_bar.custom_minimum_size.y = 28
	drag_bar.target = inventory_window
	drag_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_bar.add_theme_stylebox_override("panel", _style(Color("#493321"), Color("#987044"), 1))
	body.add_child(drag_bar)
	var title := _label("⠿  ИНВЕНТАРЬ · 32 ЯЧЕЙКИ", 11, Color("#f0d6a5"))
	title.position = Vector2(8, 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_bar.add_child(title)
	var grid_margin := MarginContainer.new()
	for pair in [["margin_left", 7], ["margin_right", 7], ["margin_top", 4], ["margin_bottom", 7]]:
		grid_margin.add_theme_constant_override(pair[0], pair[1])
	body.add_child(grid_margin)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 8
	inventory_grid.add_theme_constant_override("h_separation", 4)
	inventory_grid.add_theme_constant_override("v_separation", 4)
	grid_margin.add_child(inventory_grid)


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
	drawer.add_theme_stylebox_override("panel", _style(Color("#292019"), Color("#c09258"), 2))
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
	drawer_title = _label("АКТИВНЫЙ ЗАКАЗ", 14, Color("#f0d6a5"))
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
		drawer_content.add_child(_label("Сейчас нет активного заказа.", 11, Color("#d9c5a5")))
		return
	var item_id := current_order.item_id
	drawer_content.add_child(_label("Заказчик: %s" % current_order.client_name, 12, Color("#f0d6a5")))
	drawer_content.add_child(_label("Изделие: %s" % MATERIALS.get(item_id, {}).get("name", item_id), 11, Color("#d9c5a5")))
	drawer_content.add_child(_label("Требуемое качество: %d/100" % current_order.required_quality, 10, Color("#d9c5a5")))
	drawer_content.add_child(_label("Награда: %d монет" % current_order.reward_money, 10, Color("#d9c5a5")))
	var description := _label(current_order.description, 10, Color("#b8a58d"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drawer_content.add_child(description)
	var quality := int(item_qualities.get(item_id, 0))
	drawer_content.add_child(_label("В инвентаре: %d · качество: %d" % [int(inventory.get(item_id, 0)), quality], 10, Color("#d9c5a5")))
	var deliver := _button("Сдать изделие", 36)
	deliver.disabled = int(inventory.get(item_id, 0)) <= 0
	deliver.pressed.connect(_on_delivery_pressed)
	drawer_content.add_child(deliver)


func _add_analysis_content() -> void:
	var intro := _label("Отчёт появляется после сдачи заказа. Записи сохраняются между запусками игры.", 10, Color("#b8a58d"))
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
		history_list.add_child(_label("История пока пуста.", 10, Color("#d9c5a5")))
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
		"Расход угля: %s" % str(record.get("coal_used", 0)),
		"Результат: %s" % str(record.get("result", "Заказ сдан"))
	]:
		var label := _label(line, 10, Color("#d9c5a5"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		drawer_content.add_child(label)


func _add_blueprints_content() -> void:
	var note := _label("Тестовая справка: выбери чертёж, чтобы увидеть необходимые материалы и операции.", 10, Color("#b8a58d"))
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
	blueprint_detail = _label("Выбери чертёж из списка.", 11, Color("#f0d6a5"))
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
	var action_names: Array[String] = []
	for action_id in recipe.get("actions", []):
		action_names.append(str(ACTIONS.get(str(action_id), {}).get("name", action_id)))
	blueprint_detail.text = "Вход: %s\nОперация: %s\nВыход: %s\nУголь: %d" % [
		MATERIALS.get(input_id, {}).get("name", input_id),
		" → ".join(action_names),
		MATERIALS.get(output_id, {}).get("name", output_id),
		int(recipe.get("coal_cost", 0))
	]


func _make_drag_preview(title: String, subtitle: String, symbol: String) -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(150, 174)
	preview.add_theme_stylebox_override("panel", _style(Color("#3a2b20"), Color("#e0b36f"), 3))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	preview.add_child(body)
	var art := CenterContainer.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var symbol_label := _label(symbol, 42, Color("#e8c48e"))
	art.add_child(symbol_label)
	body.add_child(art)
	var name_label := _label(title, 12, Color("#f0d6a5"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(name_label)
	var sub_label := _label(subtitle, 9, Color("#c6ad8c"))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub_label)
	return preview


func _make_visual_card(payload: Dictionary, title: String, subtitle: String, symbol: String, tint: Color, size: Vector2) -> FullDragCard:
	var card := FullDragCard.new()
	card.host = self
	card.payload = payload.duplicate(true)
	card.title_text = title
	card.subtitle_text = subtitle
	card.symbol_text = symbol
	card.custom_minimum_size = size
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", _style(Color("#3a2b20"), tint, 2))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	card.add_child(body)
	var art := CenterContainer.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var icon_label := _label(symbol, 23 if size.x > 90 else 15, tint.lightened(0.35))
	art.add_child(icon_label)
	body.add_child(art)
	var name_label := _label(title, 10 if size.x > 90 else 8, Color("#f0d6a5"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(name_label)
	var sub_label := _label(subtitle, 8, Color("#c6ad8c"))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub_label)
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
				var payload := {"origin": "inventory", "kind": "resource", "id": id, "quality": quality}
				inventory_grid.add_child(_make_visual_card(payload, "%s ×%d" % [data.get("name", id), int(entry.count)], "Качество %d" % quality, "◆", Color("#bd9259"), Vector2(34, 62)))
			else:
				var action_data: Dictionary = ACTIONS.get(id, {})
				var payload := {"origin": "inventory", "kind": "action", "id": id}
				inventory_grid.add_child(_make_visual_card(payload, str(action_data.get("name", id)), "Карта действия", str(action_data.get("symbol", "⚒")), Color("#80a88a"), Vector2(34, 62)))
		else:
			var empty := PanelContainer.new()
			empty.custom_minimum_size = Vector2(34, 62)
			empty.add_theme_stylebox_override("panel", _style(Color("#211a15"), Color("#5c4934"), 1))
			inventory_grid.add_child(empty)


func _refresh_hand() -> void:
	if hand_list == null:
		return
	for child in hand_list.get_children():
		child.queue_free()
	for index in range(HAND_LIMIT):
		if index < hand_cards.size():
			var data: Dictionary = hand_cards[index]
			var id := str(data.id)
			if str(data.kind) == "resource":
				var material: Dictionary = MATERIALS.get(id, {})
				var quality := int(data.get("quality", 0))
				var payload := {"origin": "hand", "kind": "resource", "id": id, "uid": data.uid}
				hand_list.add_child(_make_visual_card(payload, str(material.get("name", id)), "Ресурс · качество %d" % quality, "◆", Color("#bd9259"), HAND_CARD_SIZE))
			else:
				var action: Dictionary = ACTIONS.get(id, {})
				var payload := {"origin": "hand", "kind": "action", "id": id, "uid": data.uid}
				hand_list.add_child(_make_visual_card(payload, str(action.get("name", id)), "Действие · многоразовое", str(action.get("symbol", "⚒")), Color("#80a88a"), HAND_CARD_SIZE))
		else:
			var empty := PanelContainer.new()
			empty.custom_minimum_size = HAND_CARD_SIZE
			empty.add_theme_stylebox_override("panel", _style(Color("#241d17"), Color("#66513a"), 1))
			var label := _label("ПУСТО", 8, Color("#88745d"))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.add_child(label)
			hand_list.add_child(empty)
	if hand_count_label != null:
		hand_count_label.text = "%d / %d карт" % [hand_cards.size(), HAND_LIMIT]


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
	var record := {
		"date_time": Time.get_datetime_string_from_system(),
		"client_name": current_order.client_name,
		"item_id": item_id,
		"item_name": str(MATERIALS.get(item_id, {}).get("name", item_id)),
		"quality": quality,
		"required_quality": current_order.required_quality,
		"coal_used": 0,
		"result": "Заказ сдан"
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
	super.set_order(order)
	if drawer != null and drawer.visible and drawer_mode == "order":
		_refresh_drawer()
