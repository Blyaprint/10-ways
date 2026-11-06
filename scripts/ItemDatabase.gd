extends Node
class_name ItemDatabase

# --- БАЗА ПРЕДМЕТОВ (Что можно выковать) ---
# Прочность (durability) — сколько ударов выдержит.
# Ценность (value) — базовая цена в монетах.
# Сложность (difficulty) — сколько нужно прогресса ковки.
var items: Dictionary = {
	"sword": {
		"name": "Железный меч",
		"description": "Простой, но надежный клинок.",
		"base_durability": 100,
		"base_value": 50,
		"difficulty": 3,
		"icon": "sword_icon" # Сюда потом вставим путь к картинке
	},
	"horseshoe": {
		"name": "Подкова",
		"description": "Приносит удачу крестьянам.",
		"base_durability": 40,
		"base_value": 15,
		"difficulty": 1,
		"icon": "horseshoe_icon"
	},
	"armor": {
		"name": "Кираса",
		"description": "Тяжелая защита для рыцаря.",
		"base_durability": 150,
		"base_value": 120,
		"difficulty": 5,
		"icon": "armor_icon"
	}
}

# --- БАЗА ЗАКАЗОВ (Что просят клиенты) ---
# quality_req — минимальное качество, которое устроит клиента (в процентах от 100).
# time_limit — сколько дней (или ходов) дается на выполнение.
var orders: Array[Dictionary] = [
	{
		"client_name": "Сельский кузнец",
		"item_id": "horseshoe",
		"quality_req": 40,
		"reward_money": 20,
		"time_limit": 2,
		"description": "Нужна подкова для старой лошади."
	},
	{
		"client_name": "Городская стража",
		"item_id": "sword",
		"quality_req": 60,
		"reward_money": 80,
		"time_limit": 3,
		"description": "Мечи для новобранцев. Без трещин!"
	},
	{
		"client_name": "Барон фон Кровь",
		"item_id": "armor",
		"quality_req": 85,
		"reward_money": 300,
		"time_limit": 5,
		"description": "Парадная кираса. Ни одного изъяна."
	}
]

# Вспомогательная функция для получения инфы о предмете
func get_item(item_id: String) -> Dictionary:
	if items.has(item_id):
		return items[item_id]
	return {}
