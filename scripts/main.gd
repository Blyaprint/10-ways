extends Control

@onready var order_panel: Control = get_node_or_null("GameContent/OrderPanel")
@onready var card_hand: Control = get_node_or_null("GameContent/CardHand")

var current_order: Order = null


func _ready() -> void:
	if OrderManager.active_orders.size() > 0:
		start_order(OrderManager.active_orders[0])
	else:
		print("Нет активных заказов. Вернись ко входу за новым заказом.")


func start_order(order: Order) -> void:
	current_order = order
	print("Взят заказ: ", order.description)

	if order_panel:
		order_panel.setup_order(order)

	if card_hand:
		card_hand.start_crafting(order)


func update_ui(progress: int, quality: int) -> void:
	if order_panel and order_panel.has_method("update_progress"):
		order_panel.update_progress(progress, quality)


func _on_submit_button_pressed() -> void:
	if current_order == null or card_hand == null:
		return

	var progress: int = card_hand.current_progress
	var quality: int = card_hand.current_quality
	var required_difficulty: int = ItemDB.items[current_order.item_id]["difficulty"]

	if progress >= required_difficulty:
		print("Успех! Предмет выкован.")
		OrderManager.complete_order(current_order, current_order.item_id, quality)
	else:
		print("Провал! Не хватает прогресса ковки.")
		OrderManager.failed_orders += 1
		OrderManager.active_orders.erase(current_order)

	card_hand.clear_table()

	if OrderManager.active_orders.size() > 0:
		start_order(OrderManager.active_orders[0])
	else:
		current_order = null
		print("Все заказы выполнены!")
		if order_panel:
			order_panel.clear_panel()
