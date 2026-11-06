class_name CraftingDatabase
extends RefCounted

# Данные карточной системы. Новые рецепты добавляются сюда,
# без изменения логики рабочего места.

const MATERIALS := {
	"iron": {"name": "Железо", "kind": "material", "quality": 70},
	"copper": {"name": "Медь", "kind": "material", "quality": 72},
	"coal": {"name": "Уголь", "kind": "resource", "quality": 0},
	"heated_iron": {"name": "Нагретое железо", "kind": "workpiece", "quality": 72},
	"iron_blank": {"name": "Железная заготовка", "kind": "workpiece", "quality": 80},
	"horseshoe": {"name": "Подкова", "kind": "product", "quality": 86},
	"heated_copper": {"name": "Нагретая медь", "kind": "workpiece", "quality": 74},
	"copper_blank": {"name": "Медная заготовка", "kind": "workpiece", "quality": 80},
	"copper_plate": {"name": "Медная пластина", "kind": "product", "quality": 84}
}

const ACTIONS := {
	"heat": {"name": "Нагрев печи", "symbol": "♨", "description": "Нагреть выбранный металл."},
	"forge": {"name": "Ковать", "symbol": "⚒", "description": "Изменить форму нагретой заготовки."},
	"bend": {"name": "Сгибать", "symbol": "⌁", "description": "Придать заготовке нужную форму."}
}

const RECIPES := {
	"iron_heat": {
		"input": "iron", "actions": ["heat"], "output": "heated_iron",
		"coal_cost": 1, "base_quality": 72,
		"unlock_actions": ["forge"], "unlock_recipes": ["iron_forge"]
	},
	"iron_forge": {
		"input": "heated_iron", "actions": ["forge"], "output": "iron_blank",
		"coal_cost": 0, "base_quality": 80,
		"unlock_actions": ["bend"], "unlock_recipes": ["iron_bend"]
	},
	"iron_bend": {
		"input": "iron_blank", "actions": ["bend"], "output": "horseshoe",
		"coal_cost": 0, "base_quality": 86,
		"unlock_actions": [], "unlock_recipes": []
	},
	"copper_heat": {
		"input": "copper", "actions": ["heat"], "output": "heated_copper",
		"coal_cost": 1, "base_quality": 74,
		"unlock_actions": [], "unlock_recipes": ["copper_forge"]
	},
	"copper_forge": {
		"input": "heated_copper", "actions": ["forge"], "output": "copper_blank",
		"coal_cost": 0, "base_quality": 80,
		"unlock_actions": [], "unlock_recipes": ["copper_bend"]
	},
	"copper_bend": {
		"input": "copper_blank", "actions": ["bend"], "output": "copper_plate",
		"coal_cost": 0, "base_quality": 84,
		"unlock_actions": [], "unlock_recipes": []
	}
}
