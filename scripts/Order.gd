extends Resource
class_name Order

# Данные заказа
var client_name: String = ""
var item_id: String = ""
var required_quality: int = 50
var reward_money: int = 100
var time_limit: int = 3
var description: String = ""

# Состояние
var is_completed: bool = false
var is_failed: bool = false
var time_spent: int = 0

func setup(data: Dictionary) -> void:
	client_name = data.get("client_name", "Неизвестный")
	item_id = data.get("item_id", "")
	required_quality = data.get("required_quality", 50)
	reward_money = data.get("reward_money", 50)
	time_limit = data.get("time_limit", 3)
	description = data.get("description", "")

# Проверка: выполнен ли заказ?
func check_completion(crafted_item_id: String, crafted_quality: int) -> bool:
	if is_completed or is_failed:
		return false
		
	if crafted_item_id == item_id and crafted_quality >= required_quality:
		is_completed = true
		return true
	else:
		# Если предмет не тот или качество низкое — заказ провален
		is_failed = true
		return false

# Проверка: не истекло ли время?
func advance_day() -> bool:
	time_spent += 1
	if time_spent >= time_limit:
		is_failed = true
		return true # Время вышло
	return false
