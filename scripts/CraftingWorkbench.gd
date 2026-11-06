extends Control

signal craft_completed(item_id: String, quality: int)

const MATERIALS := CraftingDatabase.MATERIALS
const ACTIONS := CraftingDatabase.ACTIONS
const RECIPES := CraftingDatabase.RECIPES

var inventory: Dictionary = {"iron": 2, "copper": 2, "coal": 3}
var item_qualities: Dictionary = {"iron": 70, "copper": 72}
var unlocked_actions: Array[String] = ["heat"]
var discovered_recipes: Array[String] = ["iron_heat"]
var experiment_attempts: Dictionary = {}
var selected_material_id := ""
var selected_actions: Array[String] = []
var current_order: Variant = null
var blueprint_used := false

var inventory_list: VBoxContainer
var action_hand: HBoxContainer
var selected_material_label: Label
var action_sequence_label: Label
var status_label: Label
var discovery_label: Label
var order_title_label: Label
var order_description_label: Label
var order_quality_label: Label
var delivery_button: Button
var craft_button: Button
var blueprint_button: Button


func _ready() -> void:
	_build_interface()
	_refresh_all()


func set_order(order: Variant) -> void:
	current_order = order
	_refresh_order()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := PanelContainer.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_theme_stylebox_override("panel", _make_style(Color("#17130f"), Color("#a77b45"), 2))
	add_child(backdrop)

	var margins := MarginContainer.new()
	for pair in [["margin_left", 12], ["margin_right", 12], ["margin_top", 10], ["margin_bottom", 10]]:
		margins.add_theme_constant_override(pair[0], pair[1])
	backdrop.add_child(margins)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margins.add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 34
	layout.add_child(header)
	var title := _make_label("КУЗНИЦА  /  РАБОЧЕЕ МЕСТО", 19, Color("#f0d6a5"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	discovery_label = _make_label("", 12, Color("#d0b78d"))
	header.add_child(discovery_label)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	layout.add_child(middle)

	var materials_section := _make_section("МАТЕРИАЛЫ", 178)
	middle.add_child(materials_section.panel)
	inventory_list = VBoxContainer.new()
	inventory_list.add_theme_constant_override("separation", 4)
	materials_section.body.add_child(inventory_list)
	var inventory_note := _make_label("Выбери заготовку для обработки.", 10, Color("#b8a58d"))
	inventory_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	materials_section.body.add_child(inventory_note)
	blueprint_button = _make_button("Изучить чертёж меди", 30)
	blueprint_button.pressed.connect(_on_blueprint_pressed)
	materials_section.body.add_child(blueprint_button)

	var process_section := _make_section("ПРОИЗВОДСТВО", 330)
	middle.add_child(process_section.panel)
	selected_material_label = _make_label("Заготовка: не выбрана", 13, Color("#f0d6a5"))
	process_section.body.add_child(selected_material_label)
	action_sequence_label = _make_label("Последовательность: —", 12, Color("#d9c5a5"))
	action_sequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	process_section.body.add_child(action_sequence_label)
	var process_hint := _make_label("Выбери материал слева, затем добавь карты действий снизу.", 11, Color("#b8a58d"))
	process_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	process_section.body.add_child(process_hint)
	status_label = _make_label("Сначала выбери материал.", 12, Color("#e7c78d"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	process_section.body.add_child(status_label)

	var process_buttons := HBoxContainer.new()
	process_section.body.add_child(process_buttons)
	craft_button = _make_button("Выполнить", 34)
	craft_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_button.pressed.connect(_on_craft_pressed)
	process_buttons.add_child(craft_button)
	var clear_button := _make_button("Очистить", 34)
	clear_button.pressed.connect(_clear_plan)
	process_buttons.add_child(clear_button)

	var order_section := _make_section("ЗАКАЗ", 178)
	middle.add_child(order_section.panel)
	order_title_label = _make_label("Нет активного заказа", 14, Color("#f0d6a5"))
	order_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_section.body.add_child(order_title_label)
	order_description_label = _make_label("Заверши цепочку производства, чтобы получить изделие.", 11, Color("#d9c5a5"))
	order_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_section.body.add_child(order_description_label)
	order_quality_label = _make_label("Качество: —", 11, Color("#d9c5a5"))
	order_section.body.add_child(order_quality_label)
	delivery_button = _make_button("Сдать изделие", 36)
	delivery_button.disabled = true
	delivery_button.pressed.connect(_on_delivery_pressed)
	order_section.body.add_child(delivery_button)

	var hand_section := _make_section("КАРТЫ ДЕЙСТВИЙ", 0)
	hand_section.panel.custom_minimum_size.y = 100
	hand_section.panel.size_flags_vertical = Control.SIZE_SHRINK_END
	layout.add_child(hand_section.panel)
	hand_section.body.add_child(_make_label("Действия многоразовые. Нагрев расходует уголь.", 10, Color("#b8a58d")))
	action_hand = HBoxContainer.new()
	action_hand.add_theme_constant_override("separation", 8)
	hand_section.body.add_child(action_hand)


func _make_section(title_text: String, min_width: float) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_style(Color("#292019"), Color("#725638"), 1))
	var margin := MarginContainer.new()
	for pair in [["margin_left", 9], ["margin_right", 9], ["margin_top", 7], ["margin_bottom", 7]]:
		margin.add_theme_constant_override(pair[0], pair[1])
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)
	body.add_child(_make_label(title_text, 12, Color("#c99b60")))
	return {"panel": panel, "body": body}


func _make_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	return style


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text_value: String, min_height: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = min_height
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color("#f2dfbd"))
	button.add_theme_color_override("font_hover_color", Color("#fff1d5"))
	button.add_theme_stylebox_override("normal", _make_style(Color("#493321"), Color("#987044"), 1))
	button.add_theme_stylebox_override("hover", _make_style(Color("#65472d"), Color("#d0a66b"), 1))
	button.add_theme_stylebox_override("pressed", _make_style(Color("#302219"), Color("#d0a66b"), 1))
	button.add_theme_stylebox_override("disabled", _make_style(Color("#302a25"), Color("#51463a"), 1))
	return button


func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_actions()
	_refresh_plan()
	_refresh_order()
	discovery_label.text = "Рецептов открыто: %d" % discovered_recipes.size()
	blueprint_button.disabled = blueprint_used


func _refresh_inventory() -> void:
	for child in inventory_list.get_children():
		child.queue_free()
	for material_id in MATERIALS.keys():
		var count := int(inventory.get(material_id, 0))
		if count <= 0:
			continue
		var data: Dictionary = MATERIALS[material_id]
		var button := _make_button("%s   × %d" % [data.name, count], 29)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = material_id == "coal"
		button.pressed.connect(_on_material_pressed.bind(str(material_id)))
		inventory_list.add_child(button)
	if inventory_list.get_child_count() == 0:
		inventory_list.add_child(_make_label("Материалов нет.", 11, Color("#b8a58d")))


func _refresh_actions() -> void:
	for child in action_hand.get_children():
		child.queue_free()
	for action_id in ACTIONS.keys():
		if not unlocked_actions.has(action_id):
			continue
		var data: Dictionary = ACTIONS[action_id]
		var button := _make_button("%s\n%s" % [data.symbol, data.name], 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = data.description
		button.pressed.connect(_on_action_pressed.bind(str(action_id)))
		action_hand.add_child(button)


func _refresh_plan() -> void:
	if selected_material_id == "":
		selected_material_label.text = "Заготовка: не выбрана"
	else:
		selected_material_label.text = "Заготовка: %s" % MATERIALS[selected_material_id].name
	if selected_actions.is_empty():
		action_sequence_label.text = "Последовательность: —"
	else:
		var names: Array[String] = []
		for action_id in selected_actions:
			names.append(str(ACTIONS[action_id].name))
		action_sequence_label.text = "Последовательность: " + " → ".join(names)
	craft_button.disabled = selected_material_id == "" or selected_actions.is_empty()


func _refresh_order() -> void:
	if current_order == null:
		order_title_label.text = "Нет активного заказа"
		order_description_label.text = "Изготовь предметы и исследуй новые рецепты."
		order_quality_label.text = "Качество: —"
		delivery_button.disabled = true
		return
	order_title_label.text = "Заказ: %s" % str(current_order.get("client_name"))
	var item_id := str(current_order.get("item_id"))
	var item_name := str(MATERIALS.get(item_id, {}).get("name", item_id))
	order_description_label.text = "Требуется: %s\nМинимальное качество: %d" % [item_name, int(current_order.get("required_quality"))]
	order_quality_label.text = "Качество изделия: %d" % int(item_qualities.get(item_id, 0))
	delivery_button.disabled = int(inventory.get(item_id, 0)) <= 0


func _on_material_pressed(material_id: String) -> void:
	selected_material_id = material_id
	selected_actions.clear()
	status_label.text = "Выбрано: %s. Теперь добавь действие." % MATERIALS[material_id].name
	_refresh_plan()


func _on_action_pressed(action_id: String) -> void:
	if selected_material_id == "":
		status_label.text = "Сначала выбери материал слева."
		return
	if selected_actions.size() >= 3:
		status_label.text = "В одной операции пока можно использовать до трёх действий."
		return
	selected_actions.append(action_id)
	status_label.text = "Добавлено действие: %s." % ACTIONS[action_id].name
	_refresh_plan()


func _on_craft_pressed() -> void:
	if selected_material_id == "" or selected_actions.is_empty():
		return
	var matching_recipe_id := ""
	var matching_recipe: Dictionary = {}
	for recipe_id in RECIPES.keys():
		var recipe: Dictionary = RECIPES[recipe_id]
		if str(recipe.input) == selected_material_id and recipe.actions == selected_actions:
			matching_recipe_id = str(recipe_id)
			matching_recipe = recipe
			break
	if matching_recipe_id == "":
		var attempt_key := selected_material_id + "|" + ",".join(selected_actions)
		experiment_attempts[attempt_key] = int(experiment_attempts.get(attempt_key, 0)) + 1
		status_label.text = "Рецепт не найден. Материал не потрачен. Попробуй изменить порядок или набор действий."
		if int(experiment_attempts[attempt_key]) >= 2:
			status_label.text += " Возможно, материалу нужна другая подготовка."
		return
	var coal_cost := int(matching_recipe.get("coal_cost", 0))
	if int(inventory.get("coal", 0)) < coal_cost:
		status_label.text = "Не хватает угля: нужно %d." % coal_cost
		return

	var was_discovered := discovered_recipes.has(matching_recipe_id)
	if not was_discovered:
		discovered_recipes.append(matching_recipe_id)
	_consume_item(selected_material_id, 1)
	if coal_cost > 0:
		_consume_item("coal", coal_cost)

	var input_quality := int(item_qualities.get(selected_material_id, 70))
	var output_id := str(matching_recipe.output)
	var output_quality := clampi(int(matching_recipe.base_quality) + int((input_quality - 70) * 0.25), 40, 100)
	inventory[output_id] = int(inventory.get(output_id, 0)) + 1
	item_qualities[output_id] = output_quality

	for action_id in matching_recipe.get("unlock_actions", []):
		if not unlocked_actions.has(str(action_id)):
			unlocked_actions.append(str(action_id))
	for recipe_id in matching_recipe.get("unlock_recipes", []):
		if not discovered_recipes.has(str(recipe_id)):
			discovered_recipes.append(str(recipe_id))

	var output_name := str(MATERIALS.get(output_id, {}).get("name", output_id))
	if not was_discovered:
		status_label.text = "Эксперимент удался! Открыт рецепт: %s. Получено: %s." % [matching_recipe_id, output_name]
	else:
		status_label.text = "Получено: %s. Качество: %d." % [output_name, output_quality]
	_clear_plan()
	_refresh_all()


func _consume_item(item_id: String, amount: int) -> void:
	var remaining := int(inventory.get(item_id, 0)) - amount
	if remaining <= 0:
		inventory.erase(item_id)
		item_qualities.erase(item_id)
	else:
		inventory[item_id] = remaining


func _clear_plan() -> void:
	selected_material_id = ""
	selected_actions.clear()
	_refresh_plan()


func _on_blueprint_pressed() -> void:
	if blueprint_used:
		return
	blueprint_used = true
	if not discovered_recipes.has("copper_heat"):
		discovered_recipes.append("copper_heat")
	status_label.text = "Изучен чертёж: нагрев меди. Теперь можно попробовать обработать медь."
	_refresh_all()


func _on_delivery_pressed() -> void:
	if current_order == null:
		return
	var item_id := str(current_order.get("item_id"))
	if int(inventory.get(item_id, 0)) <= 0:
		return
	var quality := int(item_qualities.get(item_id, 0))
	_consume_item(item_id, 1)
	craft_completed.emit(item_id, quality)
	status_label.text = "Изделие передано заказчику."
	_refresh_all()
