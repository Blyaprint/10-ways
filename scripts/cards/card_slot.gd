extends Control

var occupied_card: Node = null

@export var slot_texture: TextureRect
@export var normal_texture: Texture2D
@export var hover_texture: Texture2D

var is_hovered_by_card: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE 
	z_index = 1 

func is_point_inside(global_point: Vector2) -> bool:
	return get_global_rect().has_point(global_point)

func set_hover_state(hovered: bool) -> void:
	if is_hovered_by_card == hovered:
		return
		
	is_hovered_by_card = hovered
	
	if slot_texture:
		if hovered and hover_texture:
			slot_texture.texture = hover_texture
		elif normal_texture:
			slot_texture.texture = normal_texture

func place_card(card: Node) -> void:
	occupied_card = card
	
	# Сбрасываем масштаб карты, чтобы она встала ровно
	card.scale = Vector2(1.0, 1.0) 
	
	# Считаем позицию для идеального центра
	var slot_center = global_position + (size / 2.0)
	var card_half_size = card.size / 2.0
	var target_pos = slot_center - card_half_size
	
	# УБРАЛИ snappedf! Карта встанет ровно по математическому центру.
	# Если хочешь, чтобы она встала на целые пиксели (без полутонов), можно использовать .round()
	card.global_position = target_pos.round()
	
	card.z_index = 10 
	card.set("input_locked", true)
