class_name WorldGrid
extends Control

signal cell_clicked(cell: Vector2i)

const MIN_ZOOM: float = 0.72
const MAX_ZOOM: float = 1.8

var land_size: int = 8
var building_rows: Array[Dictionary] = []
var build_mode_id: String = ""
var selected_building_id: int = 0
var player_money: float = 0.0
var preview_cost: float = 0.0
var hover_cell: Vector2i = Vector2i(-1, -1)
var board_zoom: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var animation_time: float = 0.0
var _animation_elapsed: float = 0.0
var _building_sprites: Dictionary[String, Texture2D] = {}
var _build_animations: Dictionary[int, float] = {}
var _panning: bool = false
var _pan_mouse_origin: Vector2 = Vector2.ZERO
var _pan_offset_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(560.0, 360.0)
	for definition_id: String in ["farm", "tree_lot", "stone_quarry", "flour_mill", "warehouse", "market", "shop", "solar_plant", "wind_turbine", "coal_plant", "battery", "coal_mine", "corn_farm", "cotton_farm", "iron_mine", "copper_mine", "gas_well", "sand_quarry", "gas_plant", "steel_mill", "cement_works", "glassworks", "cable_factory", "electronics_factory", "food_factory", "textile_mill", "park"]:
		var sprite_path: String = "res://assets/sprites/%s.png" % definition_id
		if not ResourceLoader.exists(sprite_path):
			sprite_path = "res://assets/sprites/%s.svg" % definition_id
		if ResourceLoader.exists(sprite_path):
			var sprite: Texture2D = load(sprite_path) as Texture2D
			if sprite != null:
				_building_sprites[definition_id] = sprite
	queue_redraw()
	set_process(true)


func _process(delta: float) -> void:
	_animation_elapsed += maxf(delta, 0.0)
	if _animation_elapsed < 0.066:
		return
	_animation_elapsed = 0.0
	animation_time += 0.066
	for building_id: int in _build_animations.keys():
		_build_animations[building_id] += 0.066
		if _build_animations[building_id] >= 0.42:
			_build_animations.erase(building_id)
	queue_redraw()


func animate_building(building_id: int) -> void:
	_build_animations[building_id] = 0.0
	queue_redraw()


func set_game_view(current_land_size: int, current_buildings: Array[Dictionary], current_build_mode_id: String, current_selected_id: int, current_money: float, current_preview_cost: float) -> void:
	land_size = maxi(1, current_land_size)
	building_rows = current_buildings
	build_mode_id = current_build_mode_id
	selected_building_id = current_selected_id
	player_money = current_money
	preview_cost = current_preview_cost
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#182226"), true)
	var tile_size: float = _tile_size()
	var origin: Vector2 = _board_origin(tile_size)
	var board_size: float = tile_size * float(land_size)
	draw_rect(Rect2(origin - Vector2(7.0, 7.0), Vector2(board_size + 14.0, board_size + 14.0)), Color("#2b3a35"), true)
	for y: int in range(land_size):
		for x: int in range(land_size):
			var cell_rect: Rect2 = Rect2(origin + Vector2(float(x), float(y)) * tile_size, Vector2(tile_size, tile_size))
			var grass_color: Color = Color("#79a95a") if (x + y) % 2 == 0 else Color("#72a353")
			draw_rect(cell_rect, grass_color, true)
			draw_rect(cell_rect, Color("#4f7842"), false, 1.5)
	for building: Dictionary in building_rows:
		var cell_value: Variant = building.get("cell", Vector2i(-1, -1))
		if typeof(cell_value) != TYPE_VECTOR2I:
			continue
		var cell: Vector2i = cell_value
		var building_id: int = int(building.get("id", 0))
		var building_size: Vector2 = Vector2(tile_size - 10.0, tile_size - 10.0)
		var building_rect: Rect2 = Rect2(origin + Vector2(float(cell.x), float(cell.y)) * tile_size + Vector2(5.0, 5.0), building_size)
		var pop_progress: float = -1.0
		if _build_animations.has(building_id):
			pop_progress = clampf(float(_build_animations[building_id]) / 0.42, 0.0, 1.0)
			var pop_scale: float = 1.0 + 0.22 * sin(pop_progress * PI) - 0.36 * (1.0 - pop_progress)
			var pop_size: Vector2 = building_size * pop_scale
			building_rect = Rect2(building_rect.get_center() - pop_size * 0.5, pop_size)
		var color: Color = Color.from_string(str(building.get("color", "#ffffff")), Color.WHITE)
		draw_rect(building_rect, color, true)
		draw_rect(building_rect, Color("#29312d"), false, 2.0)
		var definition_id: String = str(building.get("definition_id", ""))
		if _building_sprites.has(definition_id):
			var sprite: Texture2D = _building_sprites[definition_id]
			var bob: float = sin(animation_time * 2.4 + float(building.get("id", 0)) * 0.83) * minf(1.8, tile_size * 0.025)
			var sprite_rect: Rect2 = Rect2(building_rect.position + Vector2(3.0, 3.0 + bob), building_rect.size - Vector2(6.0, 6.0))
			draw_texture_rect(sprite, sprite_rect, false)
		else:
			var font: Font = ThemeDB.fallback_font
			var glyph: String = str(building.get("glyph", "?"))
			var font_size: int = maxi(12, int(tile_size * 0.34))
			var glyph_width: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			draw_string(font, building_rect.position + Vector2((building_rect.size.x - glyph_width) * 0.5, building_rect.size.y * 0.62), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#fffdf0"))
		if pop_progress >= 0.0:
			draw_rect(building_rect.grow(3.0 + 5.0 * (1.0 - pop_progress)), Color(0.82, 1.0, 0.64, 1.0 - pop_progress), false, 2.0)
		if building_id == selected_building_id:
			draw_rect(building_rect.grow(2.0), Color("#fff0a0"), false, 3.0)
		elif float(building.get("neighbor_bonus", 0.0)) > 0.0:
			draw_rect(building_rect.grow(2.0), Color("#a4f0a4"), false, 2.0)
	if not build_mode_id.is_empty() and _inside_land(hover_cell):
		var preview_rect: Rect2 = Rect2(origin + Vector2(float(hover_cell.x), float(hover_cell.y)) * tile_size + Vector2(2.0, 2.0), Vector2(tile_size - 4.0, tile_size - 4.0))
		var valid_preview: bool = _building_at(hover_cell).is_empty() and player_money + 0.000001 >= preview_cost
		var preview_color: Color = Color("#65ef91") if valid_preview else Color("#f07870")
		draw_rect(preview_rect, Color(preview_color, 0.22), true)
		draw_rect(preview_rect, preview_color, false, 4.0)
	if not _inside_land(hover_cell):
		return
	var hover_rect: Rect2 = Rect2(origin + Vector2(float(hover_cell.x), float(hover_cell.y)) * tile_size, Vector2(tile_size, tile_size))
	draw_rect(hover_rect, Color("#f8f0b0"), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			board_zoom = minf(MAX_ZOOM, board_zoom + 0.1)
			queue_redraw()
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			board_zoom = maxf(MIN_ZOOM, board_zoom - 0.1)
			queue_redraw()
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mouse_button.pressed
			if _panning:
				_pan_mouse_origin = mouse_button.position
				_pan_offset_origin = pan_offset
			accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			var clicked_cell: Vector2i = _cell_at(mouse_button.position)
			if _inside_land(clicked_cell):
				cell_clicked.emit(clicked_cell)
			accept_event()
	elif event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _panning:
			pan_offset = _pan_offset_origin + mouse_motion.position - _pan_mouse_origin
			queue_redraw()
		else:
			var next_hover: Vector2i = _cell_at(mouse_motion.position)
			if next_hover != hover_cell:
				hover_cell = next_hover
				queue_redraw()


func _tile_size() -> float:
	var available: float = minf(size.x, size.y)
	return maxf(18.0, available / float(land_size) * 0.84 * board_zoom)


func _board_origin(tile_size: float) -> Vector2:
	var board_size: Vector2 = Vector2(tile_size * float(land_size), tile_size * float(land_size))
	return (size - board_size) * 0.5 + pan_offset


func _cell_at(local_position: Vector2) -> Vector2i:
	var tile_size: float = _tile_size()
	var local_grid_position: Vector2 = (local_position - _board_origin(tile_size)) / tile_size
	if local_grid_position.x < 0.0 or local_grid_position.y < 0.0:
		return Vector2i(-1, -1)
	return Vector2i(floori(local_grid_position.x), floori(local_grid_position.y))


func _inside_land(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < land_size and cell.y < land_size


func _building_at(cell: Vector2i) -> Dictionary:
	for building: Dictionary in building_rows:
		if building.get("cell", Vector2i(-1, -1)) == cell:
			return building
	return {}
