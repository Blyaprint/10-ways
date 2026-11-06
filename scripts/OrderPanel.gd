extends Control

@onready var client_label: Label = $Vbox/ClientLabel
@onready var description_label: Label = $Vbox/DescLabel
@onready var progress_bar: ProgressBar = $Vbox/ProgressBar
@onready var quality_bar: ProgressBar = $Vbox/QualityBar
@onready var deadline_label: Label = $Vbox/DeadlineLabel


func setup_order(order: Order) -> void:
	if order == null:
		clear_panel()
		return

	client_label.text = "Заказчик: " + order.client_name
	description_label.text = order.description
	progress_bar.value = 0
	quality_bar.value = 100
	deadline_label.text = "Срок: %d дн." % order.time_limit


func update_progress(progress: int, quality: int) -> void:
	progress_bar.value = progress
	quality_bar.value = quality


func clear_panel() -> void:
	client_label.text = ""
	description_label.text = ""
	progress_bar.value = 0
	quality_bar.value = 0
	deadline_label.text = ""
