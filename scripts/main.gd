extends Control

const CRAFTING_WORKBENCH_SCENE := preload("res://scenes/CraftingWorkbench.tscn")

@onready var order_panel: Control = get_node_or_null("GameContent/OrderPanel")
@onready var card_hand: Control = get_node_or_null("GameContent/CardHand")

var current_order: Order = null
var crafting_workbench: Control = null


func _ready() -> void:
	# Старое колесо пока сохраняем в проекте, но отключаем в игровом процессе.
	if card_hand:
		card_hand.hide()
		card_hand.set_process(false)
		card_hand.set_process_input(false)
		card_hand.set_process_unhandled_input(false)
	if order_panel:
		order_panel.hide()

	var game_content := get_node_or_null("GameContent")
	if game_content:
		crafting_workbench = CRAFTING_WORKBENCH_SCENE.instantiate()
		crafting_workbench.name = "CraftingWorkbench"
		crafting_workbench.z_index = 4097
		game_content.add_child(crafting_workbench)
		crafting_workbench.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		crafting_workbench.connect("craft_completed", Callable(self, "_on_craft_completed"))

	if OrderManager.active_orders.size() > 0:
		start_order(OrderManager.active_orders[0])
	elif crafting_workbench:
		crafting_workbench.call("set_order", null)


func start_order(order: Order) -> void:
	current_order = order
	print("Взят заказ: ", order.description)
	if crafting_workbench:
		crafting_workbench.call("set_order", order)


func _on_craft_completed(item_id: String, quality: int) -> void:
	if current_order == null:
		return
	OrderManager.complete_order(current_order, item_id, quality)
	if OrderManager.active_orders.size() > 0:
		start_order(OrderManager.active_orders[0])
	else:
		current_order = null
		if crafting_workbench:
			crafting_workbench.set_order(null)
		print("Все заказы выполнены!")
