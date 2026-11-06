extends Control

signal drag_started(card_id: String)
signal drag_released(card_id: String, global_position: Vector2)

var card_id: String = ""
var home_position: Vector2 = Vector2.ZERO
var base_z_index: int = 0

var is_hovered: bool = false
var is_dragging: bool = false
var is_flying_back: bool = false
var input_locked: bool = false
var drag_offset: Vector2 = Vector2.ZERO

const NORMAL_SCALE := Vector2(1.0, 1.0)
const HOVER_SCALE := Vector2(1.1, 1.1) 
const DRAG_SCALE := Vector2(1.2, 1.2)
const CIRCLE_SCALE := Vector2(0.6, 0.6) 

var fly_tween: Tween
var fly_start_pos: Vector2
var fly_end_pos: Vector2

@onready var border: Panel = $Border
@onready var symbol_label: Label = $Border/Content/Symbol
@onready var title_label: Label = $Border/Content/Title
@onready var description_label: Label = $Border/Content/Description
@onready var effect_label: Label = $Border/Content/Effect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP 
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pivot_offset = size / 2.0 
	
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for sub_child in child.get_children():
				if sub_child is Control:
					sub_child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_card(data: Dictionary) -> void:
	card_id = str(data.get("id", ""))
	if symbol_label: symbol_label.text = str(data.get("symbol", "?"))
	if title_label: title_label.text = str(data.get("title", ""))
	if description_label: description_label.text = str(data.get("description", ""))
	
	if effect_label:
		match str(data.get("effect", "neutral")):
			"good": effect_label.text = "▲"
			"bad":  effect_label.text = "▼"
			_:      effect_label.text = "◆"

func set_hand_transform(target_position: Vector2, _target_rotation: float, target_z_index: int) -> void:
	home_position = target_position.round()
	base_z_index = target_z_index
	
	if not is_hovered and not is_dragging and not is_flying_back:
		scale = NORMAL_SCALE
		rotation = 0.0
		position = home_position
		z_index = base_z_index

func set_input_locked(value: bool) -> void:
	if is_flying_back: return 
	input_locked = value
	if input_locked and not is_dragging:
		is_hovered = false
		if not is_flying_back:
			global_position = home_position
		z_index = base_z_index

func _on_mouse_entered() -> void:
	if is_dragging or input_locked or is_flying_back: return 
	is_hovered = true
	z_index = 1000
	if not input_locked:
		home_position = global_position 
	scale = HOVER_SCALE
	var lift = 10.0 + (size.y * (HOVER_SCALE.y - 1.0)) / 2.0
	global_position = (global_position + Vector2(0, -lift)).round()

func _on_mouse_exited() -> void:
	if is_dragging or input_locked or is_flying_back: return
	is_hovered = false
	z_index = base_z_index
	scale = NORMAL_SCALE
	global_position = home_position

func _gui_input(event: InputEvent) -> void:
	if input_locked or is_dragging or is_flying_back: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging = true
		is_hovered = false
		z_index = 4096 
		scale = DRAG_SCALE
		
		# --- ПРЫЖОК В ЦЕНТР ---
		var mouse_global = get_global_mouse_position()
		# Ставим карту так, чтобы её центр был в мышке
		global_position = mouse_global - (size * scale / 2.0)
		# Обнуляем смещение, чтобы карта летела ровно за курсором
		drag_offset = Vector2.ZERO 
		
		drag_started.emit(card_id)
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_dragging: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
		drag_released.emit(card_id, get_global_mouse_position())
		get_viewport().set_input_as_handled()

# --- ДВИЖЕНИЕ ПРИ ДРАГЕ (ОСТАЕТСЯ РЕТРО) ---
func _process(_delta: float) -> void:
	if is_dragging:
		var mouse_global = get_global_mouse_position()
		var target_global = mouse_global - (drag_offset * scale)
		# Так как drag_offset = 0, target_global = mouse_global
		# Но нам нужно вычесть половину размера, чтобы центр был в мышке
		target_global -= (size * scale / 2.0)
		
		global_position.x = snappedf(target_global.x, 10.0)
		global_position.y = snappedf(target_global.y, 10.0)

# --- ВОЗВРАТ В РУКУ С TWEEN (С ШАГОМ 10 ПИКСЕЛЕЙ) ---
func return_to_hand() -> void:
	if is_flying_back: return
	is_dragging = false
	is_hovered = false
	is_flying_back = true
	input_locked = true 
	z_index = 500 
	
	fly_start_pos = global_position
	var parent_transform = get_parent().get_global_transform_with_canvas()
	fly_end_pos = (parent_transform * home_position).round()
	
	if fly_tween and fly_tween.is_running():
		fly_tween.kill()
		
	fly_tween = create_tween()
	fly_tween.set_trans(Tween.TRANS_LINEAR)
	fly_tween.set_parallel(true)
	
	# Уменьшаем и вращаем
	fly_tween.tween_property(self, "scale", NORMAL_SCALE, 0.25)
	fly_tween.tween_property(self, "rotation", 0.0, 0.25)
	
	# Двигаем с округлением до 10 пикселей
	fly_tween.tween_method(_on_fly_step, 0.0, 1.0, 0.25)
	fly_tween.chain().tween_callback(_on_fly_finished)

func return_to_hand_safe(hand_pos: Vector2, hand_z: int) -> void:
	if is_flying_back: return
	is_dragging = false
	is_hovered = false
	is_flying_back = true
	input_locked = true 
	
	home_position = hand_pos.round()
	base_z_index = hand_z
	z_index = 500 
	
	fly_start_pos = global_position
	var parent_transform = get_parent().get_global_transform_with_canvas()
	fly_end_pos = (parent_transform * home_position).round()
	
	if fly_tween and fly_tween.is_running():
		fly_tween.kill()
		
	fly_tween = create_tween()
	fly_tween.set_trans(Tween.TRANS_LINEAR)
	fly_tween.set_parallel(true)
	
	fly_tween.tween_property(self, "scale", NORMAL_SCALE, 0.25)
	fly_tween.tween_property(self, "rotation", 0.0, 0.25)
	fly_tween.tween_method(_on_fly_step, 0.0, 1.0, 0.25)
	fly_tween.chain().tween_callback(_on_fly_finished)

func _on_fly_step(progress: float) -> void:
	var current_pos = fly_start_pos.lerp(fly_end_pos, progress)
	# ОКРУГЛЯЕМ ДО 10, чтобы было рывками
	global_position.x = snappedf(current_pos.x, 10.0)
	global_position.y = snappedf(current_pos.y, 10.0)

func _on_fly_finished() -> void:
	is_flying_back = false
	rotation = 0.0
	global_position = home_position
	z_index = base_z_index
	scale = NORMAL_SCALE
	input_locked = false

func play_card() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_dragging = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
