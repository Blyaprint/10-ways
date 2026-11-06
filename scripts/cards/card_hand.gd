extends Control

const CARD_SCENE = preload("res://scenes/cards/Card.tscn")

const CARD_WIDTH := 50.0
const CARD_HEIGHT := 100.0
const CARD_SPACING := -8.0
const HAND_BOTTOM_MARGIN := 8.0

@export var order_panel: Control
@export var wheel_node: Node2D 
@export var wheel_slots: Array[Node2D] = [] 

const ROTATION_STEP: float = 15.0 
var target_wheel_angle: float = 0.0
var current_wheel_angle: float = 0.0

var cards: Array[Control] = [] 
var dragging_card_id: String = ""
var slot_cards: Dictionary = {} 
var current_hovered_slot: Node2D = null

var current_order: Order = null

var current_progress: int = 0
var current_quality: int = 100

# Твины
var slot_tween: Tween
var wheel_tween: Tween

var card_data: Array[Dictionary] = [
	{"id": "strike", "title": "Fire", "symbol": "♨", "description": "Разжечь огонь.", "effect": "bad"},
	{"id": "leave", "title": "Mine", "symbol": "➜", "description": "Работать с металлом.", "effect": "bad"},
	{"id": "rework", "title": "Rechange", "symbol": "⚒", "description": "Изменить форму.", "effect": "good"},
	{"id": "connect", "title": "Put", "symbol": "∞", "description": "Объединить вещи.", "effect": "neutral"},
	{"id": "exchange", "title": "Exchange", "symbol": "⇄", "description": "Заменить другим.", "effect": "bad"},
	{"id": "take", "title": "Get", "symbol": "✋", "description": "Получить предмет.", "effect": "neutral"},
	{"id": "wait", "title": "Await", "symbol": "⌛", "description": "Не вмешиваться.", "effect": "neutral"},
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE 
	resized.connect(_layout_hand)
	create_hand()
	call_deferred("_layout_hand")
	
	for slot in wheel_slots:
		for child in slot.get_children():
			if child is CanvasItem:
				child.modulate.a = 0.0
	# Берем первый активный заказ при старте
	if OrderManager.active_orders.size() > 0:
		current_order = OrderManager.active_orders[0]
		print("Текущий заказ: ", current_order.description)

# Когда игрок завершает ковку (нажимает кнопку "Сдать заказ")
func submit_craft(crafted_item_id: String, crafted_quality: int) -> void:
	if current_order == null:
		return
		
	# Проверяем, выполнен ли заказ через менеджер
	OrderManager.complete_order(current_order, crafted_item_id, crafted_quality)
	
	# Берем следующий заказ
	if OrderManager.active_orders.size() > 0:
		current_order = OrderManager.active_orders[0]
		print("Новый заказ: ", current_order.description)
	else:
		current_order = null
		print("Все заказы выполнены!")

# Вызывается из Main, когда берем новый заказ
func start_crafting(order: Order) -> void:
	current_progress = 0
	current_quality = 100
	# Очищаем колесо от старых карт
	clear_table()
	print("Начинаем ковать: ", order.item_id)

# Очищает все слоты на колесе
func clear_table() -> void:
	for slot in wheel_slots:
		if slot_cards.has(slot):
			var card = slot_cards[slot]
			card.queue_free()
			slot_cards.erase(slot)
	current_progress = 0
	current_quality = 100

func create_hand() -> void:
	for data in card_data:
		var card = CARD_SCENE.instantiate() as Control
		add_child(card)
		card.call("set_card", data)
		card.connect("drag_started", _on_card_drag_started)
		card.connect("drag_released", _on_card_drag_released)
		cards.append(card)

func _process(_delta: float) -> void:
	if wheel_node:
		# Вращение теперь задается через Tween, здесь мы просто применяем текущий угол
		wheel_node.rotation_degrees = current_wheel_angle
		
		for slot in wheel_slots:
			for child in slot.get_children():
				if child is CanvasItem:
					child.rotation_degrees = -current_wheel_angle
	
	for slot in wheel_slots:
		if slot_cards.has(slot):
			var card = slot_cards[slot]
			if card != null:
				var target_pos = slot.global_position
				card.global_position = target_pos - (card.size * card.scale / 2.0)
				card.rotation = 0.0
				card.z_index = 100 

	if dragging_card_id != "":
		var mouse_pos = get_global_mouse_position()
		var new_hovered_slot = null
		var min_dist = 120.0
		
		for slot in wheel_slots:
			if not slot_cards.has(slot):
				var dist = mouse_pos.distance_to(slot.global_position)
				if dist < min_dist:
					min_dist = dist
					new_hovered_slot = slot
					
		if new_hovered_slot != current_hovered_slot:
			if current_hovered_slot != null:
				if slot_tween and slot_tween.is_running():
					slot_tween.kill()
				for child in current_hovered_slot.get_children():
					if child is CanvasItem:
						slot_tween = create_tween()
						slot_tween.tween_property(child, "modulate:a", 0.0, 0.15)
			
			current_hovered_slot = new_hovered_slot
			
			if current_hovered_slot != null:
				for child in current_hovered_slot.get_children():
					if child is CanvasItem:
						slot_tween = create_tween()
						slot_tween.tween_property(child, "modulate:a", 1.0, 0.15)
	else:
		if current_hovered_slot != null:
			if slot_tween and slot_tween.is_running():
				slot_tween.kill()
			for child in current_hovered_slot.get_children():
				if child is CanvasItem:
					slot_tween = create_tween()
					slot_tween.tween_property(child, "modulate:a", 0.0, 0.15)
			current_hovered_slot = null

func _input(event: InputEvent) -> void:
	if dragging_card_id == "": 
		var mouse_pos = get_global_mouse_position()
		var center_pos = wheel_node.global_position if wheel_node else Vector2(400, 225)
		
		if mouse_pos.distance_to(center_pos) < 200.0: 
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
					rotate_wheel(-ROTATION_STEP)
					get_viewport().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
					rotate_wheel(ROTATION_STEP)
					get_viewport().set_input_as_handled()

# --- НОВАЯ ЛОГИКА ВРАЩЕНИЯ ЧЕРЕЗ TWEEN ---
func rotate_wheel(degrees: float) -> void:
	target_wheel_angle += degrees
	
	if wheel_tween and wheel_tween.is_running():
		wheel_tween.kill()
		
	wheel_tween = create_tween()
	wheel_tween.set_trans(Tween.TRANS_SINE) # Плавный старт/финиш
	wheel_tween.set_ease(Tween.EASE_OUT)
	
	# Анимируем current_wheel_angle к target_wheel_angle за 0.25 секунды
	wheel_tween.tween_property(self, "current_wheel_angle", target_wheel_angle, 0.25)

func _layout_hand() -> void:
	var total: int = cards.size()
	if total == 0: return

	var total_width: float = (total * CARD_WIDTH + maxf(total - 1, 0) * CARD_SPACING)
	var start_x: float = (size.x - total_width) / 2.0
	var card_y: float = size.y - CARD_HEIGHT - HAND_BOTTOM_MARGIN

	for i in range(total):
		var card = cards[i]
		var card_x: float = start_x + i * (CARD_WIDTH + CARD_SPACING)
		var target_position := Vector2(roundf(card_x), roundf(card_y))
		card.call("set_hand_transform", target_position, 0.0, i)

func _on_card_drag_started(card_id: String) -> void:
	dragging_card_id = card_id
	
	var dragged_card = null
	for card in cards:
		if card.get("card_id") == card_id:
			dragged_card = card
			break

	for slot in wheel_slots:
		if slot_cards.has(slot) and slot_cards[slot] != null:
			var child = slot_cards[slot]
			if child.get("card_id") == card_id:
				dragged_card = child
				slot_cards.erase(slot)
				dragged_card.set("input_locked", false)
				break

	if dragged_card != null:
		for card in cards:
			if card != dragged_card:
				card.call("set_input_locked", true)

func _on_card_drag_released(card_id: String, global_pos: Vector2) -> void:
	var played_card = null
	for card in cards:
		if card.get("card_id") == card_id:
			played_card = card
			break

	if played_card == null: return

	var closest_slot = null
	var min_distance = 120.0 

	for slot in wheel_slots:
		if not slot_cards.has(slot): 
			var dist = global_pos.distance_to(slot.global_position)
			if dist < min_distance:
				min_distance = dist
				closest_slot = slot

	if closest_slot != null:
		cards.erase(played_card)
		slot_cards[closest_slot] = played_card 
		
		played_card.set("input_locked", true)
		played_card.scale = played_card.get("CIRCLE_SCALE")
		played_card.pivot_offset = played_card.size / 2.0
		played_card.z_index = 100
		
		_layout_hand()
	else:
		played_card.call("return_to_hand")
		_layout_hand()

	dragging_card_id = ""
	for card in cards:
		card.call("set_input_locked", false)
	
	if current_hovered_slot != null:
		if slot_tween and slot_tween.is_running():
			slot_tween.kill()
		for child in current_hovered_slot.get_children():
			if child is CanvasItem:
				slot_tween = create_tween()
				slot_tween.tween_property(child, "modulate:a", 0.0, 0.15)
		current_hovered_slot = null
	if closest_slot != null:
		cards.erase(played_card)
		slot_cards[closest_slot] = played_card 
		
		played_card.set("input_locked", true)
		played_card.scale = played_card.get("CIRCLE_SCALE")
		played_card.pivot_offset = played_card.size / 2.0
		played_card.z_index = 100
		
		# --- СЧИТАЕМ ПРОГРЕСС ---
		var card_type = played_card.get("card_id")
		if card_type == "hammer": # Если это карта молота
			current_progress += 1
		elif card_type == "crack": # Если это дебаф (трещина)
			current_quality -= 20
			
		# Обновляем панель заказа, чтобы игрок видел изменения
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("update_ui"):
			main_node.update_ui(current_progress, current_quality)
		
		_layout_hand()
