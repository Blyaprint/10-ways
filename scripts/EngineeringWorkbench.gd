extends Control

signal craft_completed(item_id: String, quality: int)

const CraftingData = preload("res://scripts/CraftingDatabase.gd")
const MATERIALS: Dictionary = CraftingData.MATERIALS
const ACTIONS: Dictionary = CraftingData.ACTIONS
const RECIPES: Dictionary = CraftingData.RECIPES
const HAND_LIMIT := 8

class DragCard extends PanelContainer:
	var host: Control
	var payload: Dictionary
	var title_text := ""

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = title_text
		preview.add_theme_color_override("font_color", Color("#f5dfb8"))
		preview.add_theme_color_override("font_size", 14)
		set_drag_preview(preview)
		return payload

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return host != null and host.call("can_drop_to_card", payload, data)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if host != null:
			host.call("drop_to_card", payload, data)


class DropZone extends PanelContainer:
	var host: Control
	var zone_kind := ""

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return host != null and host.call("can_drop_to_zone", zone_kind, data)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if host != null:
			host.call("drop_to_zone", zone_kind, data)


class GraphCanvas extends GraphEdit:
	var host: Control

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return host != null and host.call("can_drop_to_graph", data)

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if host != null:
			host.call("drop_to_graph", at_position + scroll_offset, data)


var inventory: Dictionary = {"iron": 2, "copper": 2, "coal": 3}
var item_qualities: Dictionary = {"iron": 70, "copper": 72}
var action_inventory: Dictionary = {"heat": 1}
var unlocked_actions: Array[String] = ["heat"]
var discovered_recipes: Array[String] = ["iron_heat"]
var experiment_attempts: Dictionary = {}
var hand_cards: Array[Dictionary] = []
var current_order: Order = null
var blueprint_used := false
var card_serial := 0
var node_serial := 0

var inventory_zone: DropZone
var hand_zone: DropZone
var inventory_list: VBoxContainer
var hand_list: HBoxContainer
var graph: GraphCanvas
var status_label: Label
var report_label: Label
var order_title_label: Label
var order_description_label: Label
var order_quality_label: Label
var delivery_button: Button
var blueprint_button: Button
var graph_hint: Label


func _ready() -> void:
	_build_interface()
	_refresh_all()


func set_order(order: Order) -> void:
	current_order = order
	_refresh_order()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := PanelContainer.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_theme_stylebox_override("panel", _style(Color("#17130f"), Color("#a77b45"), 2))
	add_child(backdrop)

	var margins := MarginContainer.new()
	for pair in [["margin_left", 9], ["margin_right", 9], ["margin_top", 7], ["margin_bottom", 7]]:
		margins.add_theme_constant_override(pair[0], pair[1])
	backdrop.add_child(margins)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margins.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var heading := _label("КУЗНИЦА  /  ИНЖЕНЕРНАЯ МАСТЕРСКАЯ", 17, Color("#f0d6a5"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(_label("РУКА: 8 СЛОТОВ", 11, Color("#d0b78d")))

	var upper := HBoxContainer.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.add_theme_constant_override("separation", 7)
	root.add_child(upper)

	inventory_zone = DropZone.new()
	inventory_zone.host = self
	inventory_zone.zone_kind = "inventory"
	inventory_zone.custom_minimum_size.x = 150
	inventory_zone.size_flags_horizontal = Control.SIZE_FILL
	inventory_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_zone.add_theme_stylebox_override("panel", _style(Color("#292019"), Color("#725638"), 1))
	upper.add_child(inventory_zone)
	var inv_margin := MarginContainer.new()
	for pair in [["margin_left", 7], ["margin_right", 7], ["margin_top", 6], ["margin_bottom", 6]]:
		inv_margin.add_theme_constant_override(pair[0], pair[1])
	inventory_zone.add_child(inv_margin)
	var inv_body := VBoxContainer.new()
	inv_body.add_theme_constant_override("separation", 5)
	inv_margin.add_child(inv_body)
	inv_body.add_child(_label("ИНВЕНТАРЬ", 12, Color("#c99b60")))
	inv_body.add_child(_label("Перетащи предмет в руку", 9, Color("#b8a58d")))
	var inv_scroll := ScrollContainer.new()
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_body.add_child(inv_scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_list.add_theme_constant_override("separation", 4)
	inv_scroll.add_child(inventory_list)
	blueprint_button = _button("Изучить чертёж меди", 29)
	blueprint_button.pressed.connect(_on_blueprint_pressed)
	inv_body.add_child(blueprint_button)

	var work_panel := PanelContainer.new()
	work_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work_panel.add_theme_stylebox_override("panel", _style(Color("#211a15"), Color("#725638"), 1))
	upper.add_child(work_panel)
	var work_margin := MarginContainer.new()
	for pair in [["margin_left", 7], ["margin_right", 7], ["margin_top", 6], ["margin_bottom", 6]]:
		work_margin.add_theme_constant_override(pair[0], pair[1])
	work_panel.add_child(work_margin)
	var work_body := VBoxContainer.new()
	work_body.add_theme_constant_override("separation", 4)
	work_margin.add_child(work_body)
	work_body.add_child(_label("ИНЖЕНЕРНАЯ СХЕМА", 12, Color("#c99b60")))
	graph_hint = _label("Перетащи карты из руки сюда. Соединяй выход одного узла со входом следующего.", 9, Color("#b8a58d"))
	graph_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	work_body.add_child(graph_hint)
	graph = GraphCanvas.new()
	graph.host = self
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.minimap_enabled = true
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
	var run_button := _button("Проверить и выполнить схему", 31)
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_button.pressed.connect(_on_run_graph_pressed)
	graph_buttons.add_child(run_button)
	var clear_graph_button := _button("Очистить схему", 31)
	clear_graph_button.pressed.connect(_clear_graph)
	graph_buttons.add_child(clear_graph_button)

	var side := PanelContainer.new()
	side.custom_minimum_size.x = 150
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_stylebox_override("panel", _style(Color("#292019"), Color("#725638"), 1))
	upper.add_child(side)
	var side_margin := MarginContainer.new()
	for pair in [["margin_left", 7], ["margin_right", 7], ["margin_top", 6], ["margin_bottom", 6]]:
		side_margin.add_theme_constant_override(pair[0], pair[1])
	side.add_child(side_margin)
	var side_body := VBoxContainer.new()
	side_body.add_theme_constant_override("separation", 5)
	side_margin.add_child(side_body)
	side_body.add_child(_label("АНАЛИЗ", 12, Color("#c99b60")))
	report_label = _label("Пока нет результатов.", 10, Color("#d9c5a5"))
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_body.add_child(report_label)
	side_body.add_child(_label("АКТИВНЫЙ ЗАКАЗ", 11, Color("#c99b60")))
	order_title_label = _label("Нет заказа", 11, Color("#f0d6a5"))
	order_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_body.add_child(order_title_label)
	order_description_label = _label("Создай изделие в мастерской.", 9, Color("#d9c5a5"))
	order_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_body.add_child(order_description_label)
	order_quality_label = _label("Качество: —", 9, Color("#d9c5a5"))
	side_body.add_child(order_quality_label)
	delivery_button = _button("Сдать изделие", 31)
	delivery_button.disabled = true
	delivery_button.pressed.connect(_on_delivery_pressed)
	side_body.add_child(delivery_button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_body.add_child(spacer)
	side_body.add_child(_label("Связи: выход → вход", 9, Color("#b8a58d")))

	hand_zone = DropZone.new()
	hand_zone.host = self
	hand_zone.zone_kind = "hand"
	hand_zone.custom_minimum_size.y = 105
	hand_zone.add_theme_stylebox_override("panel", _style(Color("#302219"), Color("#987044"), 1))
	root.add_child(hand_zone)
	var hand_margin := MarginContainer.new()
	for pair in [["margin_left", 7], ["margin_right", 7], ["margin_top", 5], ["margin_bottom", 5]]:
		hand_margin.add_theme_constant_override(pair[0], pair[1])
	hand_zone.add_child(hand_margin)
	var hand_body := VBoxContainer.new()
	hand_body.add_theme_constant_override("separation", 4)
	hand_margin.add_child(hand_body)
	var hand_header := HBoxContainer.new()
	hand_body.add_child(hand_header)
	hand_header.add_child(_label("РУКА", 11, Color("#c99b60")))
	var hand_count_label := _label("Перетащи сюда ресурсы и действия из инвентаря", 9, Color("#b8a58d"))
	hand_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand_header.add_child(hand_count_label)
	hand_list = HBoxContainer.new()
	hand_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_list.add_theme_constant_override("separation", 5)
	hand_body.add_child(hand_list)


func _style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(5)
	return box


func _label(value: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


func _button(value: String, height: float) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = height
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size", 10)
	result.add_theme_color_override("font_color", Color("#f2dfbd"))
	result.add_theme_stylebox_override("normal", _style(Color("#493321"), Color("#987044"), 1))
	result.add_theme_stylebox_override("hover", _style(Color("#65472d"), Color("#d0a66b"), 1))
	result.add_theme_stylebox_override("pressed", _style(Color("#302219"), Color("#d0a66b"), 1))
	return result


func _make_card(payload: Dictionary, title: String, subtitle: String, tint: Color) -> DragCard:
	var card := DragCard.new()
	card.host = self
	card.payload = payload.duplicate(true)
	card.title_text = title
	card.custom_minimum_size = Vector2(88, 58)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", _style(Color("#3a2b20"), tint, 2))
	var margin := MarginContainer.new()
	for pair in [["margin_left", 5], ["margin_right", 5], ["margin_top", 4], ["margin_bottom", 4]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	margin.add_child(body)
	var title_label := _label(title, 10, Color("#f0d6a5"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title_label)
	var sub_label := _label(subtitle, 8, Color("#c6ad8c"))
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub_label)
	return card


func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_hand()
	_refresh_order()
	blueprint_button.disabled = blueprint_used


func _refresh_inventory() -> void:
	for child in inventory_list.get_children():
		child.queue_free()
	for item_id in MATERIALS.keys():
		var count := int(inventory.get(item_id, 0))
		if count <= 0:
			continue
		var data: Dictionary = MATERIALS[item_id]
		var quality := int(item_qualities.get(item_id, data.get("quality", 0)))
		var payload := {"origin": "inventory", "kind": "resource", "id": str(item_id), "quality": quality}
		inventory_list.add_child(_make_card(payload, "%s ×%d" % [data.name, count], "Качество: %d" % quality, Color("#a77b45")))
	for action_id in ACTIONS.keys():
		if not unlocked_actions.has(action_id) or int(action_inventory.get(action_id, 0)) <= 0:
			continue
		var action_data: Dictionary = ACTIONS[action_id]
		var payload := {"origin": "inventory", "kind": "action", "id": str(action_id)}
		inventory_list.add_child(_make_card(payload, str(action_data.name), "Карта действия", Color("#70917b")))
	if inventory_list.get_child_count() == 0:
		inventory_list.add_child(_label("Инвентарь пуст.", 9, Color("#b8a58d")))


func _refresh_hand() -> void:
	for child in hand_list.get_children():
		child.queue_free()
	for index in range(HAND_LIMIT):
		if index < hand_cards.size():
			var card_data: Dictionary = hand_cards[index]
			var id := str(card_data.id)
			if str(card_data.kind) == "resource":
				var item_data: Dictionary = MATERIALS.get(id, {})
				var quality := int(card_data.get("quality", 0))
				var card := _make_card({"origin": "hand", "kind": "resource", "id": id, "uid": card_data.uid}, str(item_data.get("name", id)), "Ресурс · %d" % quality, Color("#a77b45"))
				hand_list.add_child(card)
			else:
				var action_data: Dictionary = ACTIONS.get(id, {})
				var card := _make_card({"origin": "hand", "kind": "action", "id": id, "uid": card_data.uid}, str(action_data.get("name", id)), "Действие · постоянно", Color("#70917b"))
				hand_list.add_child(card)
		else:
			var empty := PanelContainer.new()
			empty.custom_minimum_size = Vector2(65, 48)
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty.add_theme_stylebox_override("panel", _style(Color("#241d17"), Color("#66513a"), 1))
			empty.add_child(_label("ПУСТО", 8, Color("#88745d")))
			hand_list.add_child(empty)


func can_drop_to_zone(zone_kind: String, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if zone_kind == "hand":
		return str(data.get("origin", "")) == "inventory" and hand_cards.size() < HAND_LIMIT
	if zone_kind == "inventory":
		return str(data.get("origin", "")) == "hand"
	return false


func drop_to_zone(zone_kind: String, data: Variant) -> void:
	if not can_drop_to_zone(zone_kind, data):
		return
	if zone_kind == "hand":
		_move_inventory_to_hand(data)
	elif zone_kind == "inventory":
		_return_hand_card(data)
	_refresh_all()


func can_drop_to_card(_target: Dictionary, data: Variant) -> bool:
	return data is Dictionary and ((str(data.get("origin", "")) == "inventory" and hand_cards.size() < HAND_LIMIT) or str(data.get("origin", "")) == "hand")


func drop_to_card(_target: Dictionary, data: Variant) -> void:
	if not data is Dictionary:
		return
	if str(data.get("origin", "")) == "inventory":
		_move_inventory_to_hand(data)
	elif str(data.get("origin", "")) == "hand":
		_return_hand_card(data)
	_refresh_all()


func _move_inventory_to_hand(data: Dictionary) -> void:
	if hand_cards.size() >= HAND_LIMIT:
		return
	var item_id := str(data.get("id", ""))
	var kind := str(data.get("kind", ""))
	if kind == "resource":
		if int(inventory.get(item_id, 0)) <= 0:
			return
		inventory[item_id] = int(inventory[item_id]) - 1
		if int(inventory[item_id]) <= 0:
			inventory.erase(item_id)
	elif kind == "action":
		if int(action_inventory.get(item_id, 0)) <= 0:
			return
		action_inventory[item_id] = int(action_inventory[item_id]) - 1
		if int(action_inventory[item_id]) <= 0:
			action_inventory.erase(item_id)
	else:
		return
	card_serial += 1
	var card := {"uid": card_serial, "kind": kind, "id": item_id}
	if kind == "resource":
		card.quality = int(data.get("quality", item_qualities.get(item_id, 0)))
	hand_cards.append(card)
	_update_status("Карта перемещена в руку.")


func _return_hand_card(data: Dictionary) -> void:
	var uid := int(data.get("uid", -1))
	for index in range(hand_cards.size()):
		if int(hand_cards[index].uid) != uid:
			continue
		var card: Dictionary = hand_cards[index]
		var item_id := str(card.id)
		if str(card.kind) == "resource":
			inventory[item_id] = int(inventory.get(item_id, 0)) + 1
			item_qualities[item_id] = int(card.get("quality", 0))
		else:
			action_inventory[item_id] = int(action_inventory.get(item_id, 0)) + 1
		hand_cards.remove_at(index)
		_update_status("Карта возвращена в инвентарь.")
		return


func can_drop_to_graph(data: Variant) -> bool:
	if not data is Dictionary or str(data.get("origin", "")) != "hand":
		return false
	return str(data.get("kind", "")) in ["resource", "action"]


func drop_to_graph(position: Vector2, data: Dictionary) -> void:
	var kind := str(data.get("kind", ""))
	var item_id := str(data.get("id", ""))
	if kind == "resource" and str(MATERIALS.get(item_id, {}).get("kind", "")) == "resource":
		_update_status("Этот ресурс нужен для затрат операции, а не как исходная заготовка.")
		return
	node_serial += 1
	var node := GraphNode.new()
	node.name = "ProcessNode_%d" % node_serial
	node.title = str(MATERIALS.get(item_id, {}).get("name", item_id)) if kind == "resource" else str(ACTIONS.get(item_id, {}).get("name", item_id))
	node.position_offset = position
	node.custom_minimum_size = Vector2(130, 62)
	node.set_meta("kind", kind)
	node.set_meta("id", item_id)
	node.set_meta("uid", int(data.get("uid", -1)))
	var info := "Входной материал" if kind == "resource" else str(ACTIONS.get(item_id, {}).get("description", "Операция обработки"))
	var label := _label(info, 9, Color("#d9c5a5"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_child(label)
	var port_color := Color("#c99b60") if kind == "resource" else Color("#80a88a")
	node.set_slot(0, kind == "action", 0, port_color, true, 0, port_color)
	graph.add_child(node)
	_update_status("Добавлен узел: %s." % node.title)


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if from_node == to_node or _would_create_cycle(String(from_node), String(to_node)):
		_update_status("Такая связь создаст цикл. Измени направление схемы.")
		return
	if graph.is_node_connected(from_node, from_port, to_node, to_port):
		return
	graph.connect_node(from_node, from_port, to_node, to_port)
	_update_status("Узлы соединены.")


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph.disconnect_node(from_node, from_port, to_node, to_port)


func _would_create_cycle(from_name: String, to_name: String) -> bool:
	var connections: Array = graph.get_connection_list()
	var pending: Array[String] = [to_name]
	var visited: Array[String] = []
	while not pending.is_empty():
		var current: String = pending.pop_back()
		if current == from_name:
			return true
		if visited.has(current):
			continue
		visited.append(current)
		for connection in connections:
			if str(connection.from_node) == current:
				pending.append(str(connection.to_node))
	return false


func _on_run_graph_pressed() -> void:
	var nodes := graph.get_children()
	var source_node: GraphNode = null
	for child in nodes:
		if child is GraphNode and str(child.get_meta("kind", "")) == "resource":
			if source_node != null:
				_update_status("Для одной производственной цепочки нужен один исходный материал.")
				return
			source_node = child
	if source_node == null:
		_update_status("Перетащи исходный материал из руки в рабочую область.")
		return
	var source_id := str(source_node.get_meta("id", ""))
	var source_uid := int(source_node.get_meta("uid", -1))
	var source_card_index := _find_hand_card_index(source_uid)
	if source_card_index < 0:
		_update_status("Исходная карта больше не находится в руке.")
		return

	var action_ids: Array[String] = []
	var current_node_name := String(source_node.name)
	var visited: Array[String] = []
	while true:
		var next_node_name := ""
		for connection in graph.get_connection_list():
			if str(connection.from_node) == current_node_name:
				if next_node_name != "":
					_update_status("В первой версии у одного узла может быть только одна следующая операция.")
					return
				next_node_name = str(connection.to_node)
		if next_node_name == "":
			break
		if visited.has(next_node_name):
			_update_status("В схеме обнаружен повтор узла.")
			return
		visited.append(next_node_name)
		var next_node := graph.get_node_or_null(NodePath(next_node_name)) as GraphNode
		if next_node == null or str(next_node.get_meta("kind", "")) != "action":
			_update_status("После материала должна идти карта действия.")
			return
		action_ids.append(str(next_node.get_meta("id", "")))
		current_node_name = next_node_name
	if action_ids.is_empty():
		_update_status("Соедини материал хотя бы с одной картой действия.")
		return
	if action_ids.size() != graph.get_connection_list().size():
		_update_status("Пока поддерживается одна непрерывная цепочка без ответвлений.")
		return

	var current_item := source_id
	var total_coal := 0
	var final_quality := int(hand_cards[source_card_index].get("quality", item_qualities.get(source_id, 70)))
	var found_recipes: Array[String] = []
	for action_id in action_ids:
		var matched: Dictionary = {}
		var matched_id := ""
		for recipe_id in RECIPES.keys():
			var recipe: Dictionary = RECIPES[recipe_id]
			if str(recipe.get("input", "")) == current_item and recipe.get("actions", []) == [action_id]:
				matched = recipe
				matched_id = str(recipe_id)
				break
		if matched.is_empty():
			_update_status("Нет известной операции «%s» для материала «%s»." % [ACTIONS.get(action_id, {}).get("name", action_id), MATERIALS.get(current_item, {}).get("name", current_item)])
			return
		total_coal += int(matched.get("coal_cost", 0))
		final_quality = clampi(int(matched.get("base_quality", final_quality)) + int((final_quality - 70) * 0.25), 40, 100)
		current_item = str(matched.get("output", ""))
		found_recipes.append(matched_id)
	if int(inventory.get("coal", 0)) < total_coal:
		_update_status("Для этой схемы нужно угля: %d. В инвентаре: %d." % [total_coal, int(inventory.get("coal", 0))])
		return

	var was_new := false
	for recipe_id in found_recipes:
		if not discovered_recipes.has(recipe_id):
			discovered_recipes.append(recipe_id)
			was_new = true
	_consume_hand_resource(source_uid)
	if total_coal > 0:
		inventory["coal"] = int(inventory.get("coal", 0)) - total_coal
		if int(inventory["coal"]) <= 0:
			inventory.erase("coal")
	inventory[current_item] = int(inventory.get(current_item, 0)) + 1
	item_qualities[current_item] = final_quality
	_unlock_actions_for_recipes(found_recipes)
	report_label.text = "Схема выполнена.\nОпераций: %d\nУголь: %d\nИтог: %s\nКачество: %d/100" % [action_ids.size(), total_coal, MATERIALS.get(current_item, {}).get("name", current_item), final_quality]
	_update_status("Производство завершено%s." % (" · открыты новые рецепты" if was_new else ""))
	_clear_graph()
	_refresh_all()


func _unlock_actions_for_recipes(recipe_ids: Array[String]) -> void:
	for recipe_id in recipe_ids:
		var recipe: Dictionary = RECIPES.get(recipe_id, {})
		for action_id in recipe.get("unlock_actions", []):
			var id := str(action_id)
			if not unlocked_actions.has(id):
				unlocked_actions.append(id)
				action_inventory[id] = 1
		for next_recipe in recipe.get("unlock_recipes", []):
			if not discovered_recipes.has(str(next_recipe)):
				discovered_recipes.append(str(next_recipe))


func _find_hand_card_index(uid: int) -> int:
	for index in range(hand_cards.size()):
		if int(hand_cards[index].uid) == uid:
			return index
	return -1


func _consume_hand_resource(uid: int) -> void:
	var index := _find_hand_card_index(uid)
	if index >= 0:
		hand_cards.remove_at(index)


func _consume_item(item_id: String, amount: int) -> void:
	var remaining := int(inventory.get(item_id, 0)) - amount
	if remaining <= 0:
		inventory.erase(item_id)
		item_qualities.erase(item_id)
	else:
		inventory[item_id] = remaining


func _clear_graph() -> void:
	for child in graph.get_children():
		if child is GraphNode:
			child.queue_free()


func _on_blueprint_pressed() -> void:
	if blueprint_used:
		return
	blueprint_used = true
	if not discovered_recipes.has("copper_heat"):
		discovered_recipes.append("copper_heat")
	_update_status("Изучен чертёж меди. Теперь доступна цепочка её обработки.")
	_refresh_all()


func _refresh_order() -> void:
	if current_order == null:
		order_title_label.text = "Нет активного заказа"
		order_description_label.text = "Изготовь предмет и проверь его качество."
		order_quality_label.text = "Качество: —"
		delivery_button.disabled = true
		return
	order_title_label.text = current_order.client_name
	var item_id := current_order.item_id
	order_description_label.text = "Нужно: %s\nМинимум: %d" % [MATERIALS.get(item_id, {}).get("name", item_id), current_order.required_quality]
	order_quality_label.text = "Качество: %d" % int(item_qualities.get(item_id, 0))
	delivery_button.disabled = int(inventory.get(item_id, 0)) <= 0


func _on_delivery_pressed() -> void:
	if current_order == null:
		return
	var item_id := current_order.item_id
	if int(inventory.get(item_id, 0)) <= 0:
		return
	var quality := int(item_qualities.get(item_id, 0))
	_consume_item(item_id, 1)
	craft_completed.emit(item_id, quality)
	_update_status("Изделие передано заказчику.")
	_refresh_all()


func _update_status(value: String) -> void:
	if status_label != null:
		status_label.text = value
	else:
		report_label.text = value
