extends Control

const KATRINE_DIALOGUE: Array[String] = [
	"Здравствуй. Ты ведь сын кузнеца?",
	"Да. Что тебе нужно?",
	"Мне нужна подкова для лошади. Твой отец обычно помогал мне с такими вещами.",
	"Я могу попробовать сделать её.",
	"Тогда договорились. Рассчитываю на тебя."
]

@onready var dialogue_label: Label = $TEXTBOX_Talk_NPC
@onready var dialogue_shadow: Label = $TEXTBOX_Talk_NPC2
@onready var continue_button: Button = $GameContent/ContinueButton
@onready var forge_button: Button = $GameContent/GoToForgeButton

var dialogue_index: int = 0


func _ready() -> void:
	# На входе пока показываем диалог, а кузнечные карты оставляем для Main.
	$CardHand.visible = false
	forge_button.visible = false
	continue_button.pressed.connect(_on_continue_button_pressed)

	if OrderManager.katrine_order_taken:
		_show_order_already_taken()
	else:
		_show_dialogue_line()


func _show_dialogue_line() -> void:
	var line := KATRINE_DIALOGUE[dialogue_index]
	dialogue_label.text = line
	dialogue_shadow.text = line
	dialogue_label.visible = true
	dialogue_shadow.visible = true
	continue_button.visible = true
	continue_button.text = "Далее" if dialogue_index < KATRINE_DIALOGUE.size() - 1 else "Принять заказ"


func _on_continue_button_pressed() -> void:
	if dialogue_index < KATRINE_DIALOGUE.size() - 1:
		dialogue_index += 1
		_show_dialogue_line()
		return

	if OrderManager.accept_katrine_order():
		dialogue_label.text = "Спасибо. Буду ждать подкову."
		dialogue_shadow.text = dialogue_label.text
	else:
		dialogue_label.text = "Я уже передала тебе свой заказ."
		dialogue_shadow.text = dialogue_label.text

	continue_button.visible = false
	forge_button.visible = true


func _show_order_already_taken() -> void:
	dialogue_label.text = "Ты уже взял мой заказ. Надеюсь, подкова скоро будет готова."
	dialogue_shadow.text = dialogue_label.text
	dialogue_label.visible = true
	dialogue_shadow.visible = true
	continue_button.visible = false
	forge_button.visible = true


func _on_go_to_forge_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
