extends Control

# Ссылки на узлы (перетащи в инспекторе)
@export var order_panel: Control
@export var card_hand: Control

var current_order: Order = null

func _ready() -> void:
	# Проверяем, есть ли заказы в менеджере
	if OrderManager.active_orders.size() > 0:
		start_order(OrderManager.active_orders[0])
	else:
		print("Нет доступных заказов!")

func start_order(order: Order) -> void:
	current_order = order
	print("Взят заказ: ", order.description)
	
	# Передаем заказ в панель (чтобы отобразился текст)
	if order_panel:
		order_panel.setup_order(order)
	
	# Говорим руке, какой заказ мы выполняем
	if card_hand:
		card_hand.start_crafting(order)

# Эта функция вызывается, когда игрок нажимает "СДАТЬ ЗАКАЗ"
func _on_submit_button_pressed() -> void:
	if current_order == null:
		return
		
	# Берем прогресс из CardHand
	var progress = card_hand.current_progress
	var quality = card_hand.current_quality
	var required_difficulty = ItemDB.items[current_order.item_id]["difficulty"]
	
	# Проверяем, достаточно ли прогресса (собрали ли мы рецепт)
	if progress >= required_difficulty:
		print("Успех! Предмет выкован.")
		# Передаем в менеджер для проверки качества
		OrderManager.complete_order(current_order, current_order.item_id, quality)
	else:
		print("Провал! Не хватает прогресса ковки.")
		# Штраф или просто неудача
		OrderManager.failed_orders += 1
	
	# Очищаем колесо и берем следующий заказ
	card_hand.clear_table()
	
	if OrderManager.active_orders.size() > 0:
		start_order(OrderManager.active_orders[0])
	else:
		print("Все заказы выполнены!")
		order_panel.clear_panel()
