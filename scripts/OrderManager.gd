extends Node

var active_orders: Array[Order] = []
var completed_orders: int = 0
var failed_orders: int = 0
var money: int = 0

func _ready() -> void:
	# Генерируем тестовые заказы при старте
	create_test_orders()

func create_test_orders() -> void:
	# Заказ 1: Подкова
	var order1 = Order.new()
	order1.setup({
		"client_name": "Крестьянин",
		"item_id": "horseshoe",
		"required_quality": 40,
		"reward_money": 20,
		"time_limit": 2,
		"description": "Нужна подкова для лошади."
	})
	active_orders.append(order1)
	
	# Заказ 2: Меч
	var order2 = Order.new()
	order2.setup({
		"client_name": "Стражник",
		"item_id": "sword",
		"required_quality": 60,
		"reward_money": 80,
		"time_limit": 3,
		"description": "Меч для службы."
	})
	active_orders.append(order2)

# Проверка завершения текущего заказа
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

# Следующий день (проверка дедлайнов)
func next_day() -> void:
	for order in active_orders.duplicate():
		if order.advance_day():
			print("Заказ от ", order.client_name, " провален (время вышло).")
			failed_orders += 1
			active_orders.erase(order)
