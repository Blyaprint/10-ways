extends Node

var active_orders: Array[Order] = []
var completed_orders: int = 0
var failed_orders: int = 0
var money: int = 0
var katrine_order_taken: bool = false


func add_order(order: Order) -> bool:
	if order == null:
		return false
	active_orders.append(order)
	return true


func accept_katrine_order() -> bool:
	if katrine_order_taken:
		return false

	var order := Order.new()
	order.setup({
		"client_name": "Катрина",
		"item_id": "horseshoe",
		"required_quality": 40,
		"reward_money": 20,
		"time_limit": 2,
		"description": "Нужна подкова для лошади."
	})

	if not add_order(order):
		return false

	katrine_order_taken = true
	return true


func complete_order(order: Order, crafted_item_id: String, crafted_quality: int) -> void:
	if order.check_completion(crafted_item_id, crafted_quality):
		print("Заказ выполнен! +", order.reward_money, " монет.")
		money += order.reward_money
		completed_orders += 1
		active_orders.erase(order)
	else:
		print("Заказ провален! Качество или предмет не те.")
		failed_orders += 1
		active_orders.erase(order)


func next_day() -> void:
	for order in active_orders.duplicate():
		if order.advance_day():
			print("Заказ от ", order.client_name, " провален (время вышло).")
			failed_orders += 1
			active_orders.erase(order)
