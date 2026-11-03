extends Control

const BUILDING_CATEGORIES: Array[String] = ["کشاورزی", "معدن", "کارخانه", "خدمات", "نیروگاه", "زیرساخت", "شهرسازی"]
const SPEEDS: Array[float] = [0.0, 1.0, 2.0, 5.0]
const RESOURCE_ICONS: Dictionary[String, String] = {
	"wheat": "🌾", "wood": "🪵", "stone": "🪨", "flour": "🥣", "coal": "⚫",
	"corn": "🌽", "cotton": "☁️", "iron": "⛓️", "copper": "🟠", "gas": "🔥",
	"sand": "🏖️", "steel": "🔩", "cement": "🧱", "glass": "🧪", "cable": "🔌",
	"electronics": "💡", "food": "🥫", "clothing": "👕",
	"rubber": "🌳", "tire": "🛞", "car_paint": "🎨",
	"engine": "⚙️", "car_body": "🚗", "car": "🏎️"
}
const WorldGrid = preload("res://src/presentation/world_grid.gd")

const TREE_CHAINS: Array = [
	{"icon": "🏎️", "title": "خودرو", "final": "car"},
	{"icon": "💡", "title": "الکترونیک", "final": "electronics"},
	{"icon": "🥫", "title": "غذا", "final": "food"},
	{"icon": "👕", "title": "پوشاک", "final": "clothing"},
	{"icon": "🥣", "title": "آرد", "final": "flour"},
	{"icon": "🧱", "title": "سیمان", "final": "cement"},
]

var _catalog: GameCatalog = GameCatalog.new()
var _simulation: Simulation = Simulation.new()
var _save_service: SaveService = SaveService.new()
var _grid: WorldGrid
var _header_money: Label
var _header_income: Label
var _header_storage: Label
var _header_power: Label
var _notice_label: Label
var _notice_panel: PanelContainer
var _inventory_amounts: Dictionary[String, Label] = {}
var _inventory_icons: Dictionary[String, Label] = {}
var _selection_title: Label
var _selection_info: Label
var _upgrade_button: Button
var _demolish_button: Button
var _speed_picker: OptionButton
var _market_summary: Label
var _progress_summary: Label
var _progress_bar: ProgressBar
var _expand_button: Button
var _prestige_button: Button
var _shop_status: Label
var _sound_toggle: CheckButton
var _fullscreen_button: Button
var _market_controls: Array[Dictionary] = []
var _shop_panel: PanelContainer
var _market_panel: PanelContainer
var _build_panel: PanelContainer
var _progress_panel: PanelContainer
var _inspector_panel: PanelContainer
var _overlay_layer: Control
var _popup_backdrop: ColorRect
var _active_popup: Control
var _notice_tween: Tween
var _popup_tween: Tween
var _inspector_tween: Tween
var _progress_tween: Tween
var _last_displayed_notice: String = ""
var _progress_target: float = -1.0
var _pulse_tweens: Dictionary = {}
var _shop_controls: Array[Dictionary] = []
var _build_buttons: Dictionary[String, Button] = {}
var _route_buttons: Dictionary = {}
var _route_state_labels: Dictionary = {}
var _tree_rows: Array[Dictionary] = []
var _tree_collapsed: Dictionary = {}
var _tree_search: String = ""
var _tree_count_labels: Dictionary = {}
var _toolbar_buttons: Dictionary[String, Button] = {}
var _confirmation_dialog: ConfirmationDialog
var _prestige_dialog: ConfirmationDialog
var _offline_dialog: AcceptDialog
var _audio_player: AudioStreamPlayer
var _build_mode_id: String = ""
var _selected_building_id: int = 0
var _speed: float = 1.0
var _simulation_accumulator: float = 0.0
var _autosave_elapsed: float = 0.0
var _saving_enabled: bool = true
var _notice: String = ""
var _offline_report: String = ""


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	if not _catalog.load_from_files("res://data/resources.json", "res://data/recipes.json", "res://data/buildings.json", "res://data/balance.json"):
		_show_boot_error()
		return
	_simulation.initialize(_catalog)
	_load_saved_game()
	_build_layout()
	if not _offline_report.is_empty():
		_offline_dialog.dialog_text = _offline_report
		_offline_dialog.popup_centered(Vector2i(520, 220))
	_refresh_ui()
	set_process(true)


func _process(delta: float) -> void:
	if _simulation.catalog == null:
		return
	var results: Array[CommandResult] = _simulation.process_commands()
	for result: CommandResult in results:
		_notice = result.message
		if result.succeeded and result.code == "built":
			_selected_building_id = result.subject_id
			_grid.animate_building(result.subject_id)
		elif result.succeeded and result.code == "upgraded":
			_grid.animate_building(result.subject_id)
		if result.succeeded:
			_play_ui_sound()
	if _speed > 0.0:
		_simulation_accumulator = minf(_simulation_accumulator + maxf(delta, 0.0) * _speed, _catalog.balance.max_backlog_seconds)
		var steps: int = 0
		while _simulation_accumulator + 0.0000001 >= _catalog.balance.tick_seconds and steps < _catalog.balance.max_steps_per_frame:
			_simulation.tick(_catalog.balance.tick_seconds)
			_simulation_accumulator -= _catalog.balance.tick_seconds
			steps += 1
		_autosave_elapsed += maxf(delta, 0.0)
		if _autosave_elapsed >= _catalog.balance.autosave_seconds:
			_save_game(true)
			_autosave_elapsed = 0.0
	_refresh_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _saving_enabled:
		_save_game(true)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		if _active_popup != null:
			_close_popup()
		elif not _build_mode_id.is_empty():
			_cancel_build_mode()
		else:
			_selected_building_id = 0
		get_viewport().set_input_as_handled()
		_refresh_ui()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_RIGHT or not mouse_button.pressed:
		return
	if _active_popup != null:
		_close_popup()
	if not _build_mode_id.is_empty():
		_build_mode_id = ""
		_notice = "ساخت لغو شد."
	elif _selected_building_id > 0:
		_selected_building_id = 0
		_notice = "انتخاب لغو شد."
	_refresh_ui()
	get_viewport().set_input_as_handled()


func _load_saved_game() -> void:
	var result: Dictionary = _save_service.load_state(_catalog)
	if bool(result.get("ok", false)):
		var loaded_state: GameState = result.get("state") as GameState
		var rollback_state: GameState = loaded_state.copy_state()
		var working_simulation: Simulation = Simulation.new()
		working_simulation.initialize(_catalog)
		if not working_simulation.restore_state(loaded_state):
			_notice = "ساختار ذخیره با داده‌های فعلی سازگار نبود؛ بازی تازه آغاز شد."
			return
		var migrated: bool = bool(result.get("migrated", false))
		var starting_money_adjusted: bool = bool(result.get("starting_money_adjusted", false))
		var money_before_offline: float = loaded_state.money
		var inventory_before_offline: Dictionary = loaded_state.inventory.duplicate()
		var now: int = int(Time.get_unix_time_from_system())
		var saved_at: int = int(result.get("saved_unix_time", now))
		var elapsed_real: int = maxi(0, now - saved_at)
		var offline_seconds: int = mini(elapsed_real, _catalog.balance.offline_cap_seconds)
		var whole_offline_seconds: int = _save_service.advance_offline(working_simulation, offline_seconds)
		var changed_state: bool = migrated or whole_offline_seconds > 0
		var changes_committed: bool = not changed_state
		if changed_state:
			var committed: Dictionary = _save_service.save_state(working_simulation.state)
			if bool(committed.get("ok", false)):
				loaded_state = working_simulation.state
				changes_committed = true
			else:
				loaded_state = rollback_state
				if starting_money_adjusted:
					loaded_state.money = float(result.get("saved_money_before_migration", loaded_state.money))
				_notice = "تغییرات آفلاین/مهاجرت ذخیره نشد؛ برای جلوگیری از پاداش تکراری، این بار اعمال نشد."
		if not _simulation.restore_state(loaded_state):
			_notice = "ساختار ذخیره با داده‌های فعلی سازگار نبود؛ بازی تازه آغاز شد."
			return
		if changed_state and offline_seconds > 0 and changes_committed:
			_offline_report = _make_offline_report(money_before_offline, inventory_before_offline, offline_seconds, elapsed_real > _catalog.balance.offline_cap_seconds, migrated, starting_money_adjusted)
			_notice = "زمان آفلاین محاسبه شد؛ گزارش درآمد و تولید آماده است."
		elif migrated and changes_committed:
			if starting_money_adjusted:
				_notice = "ذخیرهٔ قدیمی به‌روز شد و موجودی شروع به $%s افزایش یافت." % _format_money(_simulation.state.money - float(result.get("saved_money_before_migration", _simulation.state.money)))
			else:
				_notice = "ذخیرهٔ قبلی به نسخهٔ جدید ارتقا یافت؛ مسیرهای بازشده حفظ شدند."
		elif not changed_state:
			_notice = "بازی قبلی بارگذاری شد."
	elif bool(result.get("unsupported_newer", false)):
		_saving_enabled = false
		_notice = str(result.get("message", "ذخیره از نسخهٔ جدیدتر است."))
	elif not bool(result.get("missing", false)):
		_notice = str(result.get("message", "ذخیره بارگذاری نشد."))


func _make_offline_report(previous_money: float, previous_inventory: Dictionary, seconds: int, capped: bool, migrated: bool, starting_money_adjusted: bool) -> String:
	var hours: int = int(seconds / 3600)
	var minutes: int = int((seconds % 3600) / 60)
	var remaining_seconds: int = seconds % 60
	var lines: Array[String] = ["در نبود بازی، %d ساعت و %d دقیقه و %d ثانیه شبیه‌سازی شد%s." % [hours, minutes, remaining_seconds, " (سقف ۸ ساعت)" if capped else ""]]
	var cash_delta: float = _simulation.state.money - previous_money
	lines.append("تغییر پول: %s$%s" % ["+" if cash_delta >= 0.0 else "−", _format_money(absf(cash_delta))])
	if migrated:
		lines.append("ذخیره به نسخهٔ جدید ارتقا یافت و قفل مسیرهای قبلی حفظ شد.")
	if starting_money_adjusted:
		lines.append("ذخیرهٔ قدیمی هم به نسخهٔ جدید ارتقا یافت و حداقل پول شروع $%s اعمال شد." % _format_money(_catalog.balance.initial_money))
	var inventory_changes: Array[String] = []
	for resource_id: String in _catalog.resource_ids():
		var delta_amount: float = float(_simulation.state.inventory.get(resource_id, 0.0)) - float(previous_inventory.get(resource_id, 0.0))
		if absf(delta_amount) > 0.05:
			inventory_changes.append("%s %s%s" % [_catalog.resources[resource_id].name_fa, "+" if delta_amount > 0.0 else "−", _format_amount(absf(delta_amount))])
	lines.append("تغییر موجودی: %s" % ("، ".join(inventory_changes) if not inventory_changes.is_empty() else "بدون تغییر قابل‌توجه"))
	lines.append("محاسبه با همان محدودیت‌های انبار، ورودی و برق انجام شد؛ بازهٔ آفلاین حداکثر ۸ ساعت است.")
	return "\n".join(lines)


func _build_layout() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("#182226")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 10.0
	layout.offset_top = 8.0
	layout.offset_right = -10.0
	layout.offset_bottom = -18.0
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	layout.add_child(_build_header())
	layout.add_child(_build_inventory_strip())
	var world_panel: PanelContainer = PanelContainer.new()
	world_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var world_margin: MarginContainer = MarginContainer.new()
	world_margin.add_theme_constant_override("margin_left", 12)
	world_margin.add_theme_constant_override("margin_right", 12)
	world_margin.add_theme_constant_override("margin_top", 12)
	world_margin.add_theme_constant_override("margin_bottom", 12)
	world_panel.add_child(world_margin)
	_grid = WorldGrid.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.cell_clicked.connect(_on_grid_cell_clicked)
	world_margin.add_child(_grid)
	layout.add_child(world_panel)
	layout.add_child(_build_action_bar())
	_overlay_layer = Control.new()
	_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_layer)
	_popup_backdrop = ColorRect.new()
	_popup_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_backdrop.color = Color(0.02, 0.035, 0.04, 0.42)
	_popup_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_backdrop.visible = false
	_popup_backdrop.z_index = 10
	_popup_backdrop.gui_input.connect(_on_popup_backdrop_input)
	_overlay_layer.add_child(_popup_backdrop)
	_build_panel = _build_build_panel()
	_market_panel = _build_market_panel()
	_progress_panel = _build_progress_panel()
	_inspector_panel = _build_inspector_panel()
	_shop_panel = _build_shop_panel()
	_notice_panel = PanelContainer.new()
	_style_panel(_notice_panel, Color("#253630"), Color("#a4ce7c"))
	_notice_label = _make_label("", 14, Color("#eaf1e5"))
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.custom_minimum_size = Vector2(360.0, 28.0)
	_notice_panel.add_child(_notice_label)
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_panel.visible = false
	_notice_panel.z_index = 8
	_notice_panel.anchor_left = 0.5
	_notice_panel.anchor_right = 0.5
	_notice_panel.anchor_top = 1.0
	_notice_panel.anchor_bottom = 1.0
	_notice_panel.offset_left = -190.0
	_notice_panel.offset_right = 190.0
	_notice_panel.offset_top = -126.0
	_notice_panel.offset_bottom = -82.0
	_overlay_layer.add_child(_notice_panel)
	_confirmation_dialog = ConfirmationDialog.new()
	_confirmation_dialog.title = "تأیید حذف"
	_confirmation_dialog.get_ok_button().text = "حذف"
	_confirmation_dialog.get_cancel_button().text = "انصراف"
	_confirmation_dialog.confirmed.connect(_confirm_demolition)
	add_child(_confirmation_dialog)
	_prestige_dialog = ConfirmationDialog.new()
	_prestige_dialog.title = "تأیید پرستیژ"
	_prestige_dialog.get_ok_button().text = "بازنشانی و دریافت پاداش"
	_prestige_dialog.get_cancel_button().text = "انصراف"
	_prestige_dialog.confirmed.connect(_confirm_prestige)
	add_child(_prestige_dialog)
	_offline_dialog = AcceptDialog.new()
	_offline_dialog.title = "گزارش زمان آفلاین"
	_offline_dialog.get_ok_button().text = "ادامهٔ بازی"
	add_child(_offline_dialog)
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = _make_ui_sound()
	add_child(_audio_player)


func _build_header() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	_style_panel(panel, Color("#202d30"), Color("#4c6656"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var title: Label = _make_label("Industrial Frontier", 18, Color("#ecf4e4"))
	title.custom_minimum_size.x = 142.0
	row.add_child(title)
	_header_money = _make_label("$0", 15, Color("#f1d37d"))
	_header_money.custom_minimum_size.x = 92.0
	_header_money.tooltip_text = "دارایی"
	row.add_child(_header_money)
	_header_income = _make_label("+$0/s", 14, Color("#9fe0aa"))
	_header_income.custom_minimum_size.x = 94.0
	_header_income.tooltip_text = "درآمد در ثانیه"
	row.add_child(_header_income)
	_header_storage = _make_label("0/0", 14, Color("#d3e0d0"))
	_header_storage.custom_minimum_size.x = 88.0
	_header_storage.tooltip_text = "فضای انبار"
	row.add_child(_header_storage)
	_header_power = _make_label("⚡ 100%", 14, Color("#a8d89f"))
	_header_power.custom_minimum_size.x = 75.0
	row.add_child(_header_power)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_speed_picker = OptionButton.new()
	_speed_picker.custom_minimum_size.x = 78.0
	_speed_picker.add_item("توقف")
	_speed_picker.add_item("×۱")
	_speed_picker.add_item("×۲")
	_speed_picker.add_item("×۵")
	_speed_picker.select(1)
	_speed_picker.item_selected.connect(_on_speed_selected)
	row.add_child(_speed_picker)
	var save_button: Button = Button.new()
	save_button.text = "ذخیره"
	save_button.custom_minimum_size.x = 68.0
	save_button.pressed.connect(_save_game.bind(false))
	row.add_child(save_button)
	_sound_toggle = CheckButton.new()
	_sound_toggle.text = "صدا"
	_sound_toggle.tooltip_text = "صدای کوتاه رابط بازی را روشن یا خاموش می‌کند."
	_sound_toggle.button_pressed = _simulation.state.sound_enabled
	_sound_toggle.toggled.connect(_on_sound_toggled)
	row.add_child(_sound_toggle)
	_fullscreen_button = Button.new()
	_fullscreen_button.custom_minimum_size.x = 90.0
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	row.add_child(_fullscreen_button)
	panel.custom_minimum_size.y = 60.0
	return panel


func _build_inventory_strip() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	_style_panel(panel, Color("#202d30"), Color("#354c43"))
	panel.custom_minimum_size.y = 52.0
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.add_child(_make_label("کالاها", 12, Color("#aabdb2")))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var chips: HBoxContainer = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 5)
	for resource_id: String in _catalog.resource_ids():
		var definition: ResourceDefinition = _catalog.resources[resource_id]
		var chip: PanelContainer = PanelContainer.new()
		_style_panel(chip, Color("#263638"), Color("#40554b"))
		chip.custom_minimum_size = Vector2(92.0, 36.0)
		var chip_row: HBoxContainer = HBoxContainer.new()
		chip_row.add_theme_constant_override("separation", 5)
		var swatch: ColorRect = ColorRect.new()
		swatch.color = Color(definition.color_hex)
		swatch.custom_minimum_size = Vector2(6.0, 22.0)
		chip_row.add_child(swatch)
		var labels: VBoxContainer = VBoxContainer.new()
		labels.add_theme_constant_override("separation", 0)
		var name_label: Label = _make_label(definition.name_fa, 10, Color("#c5d6c0"))
		name_label.custom_minimum_size.x = 68.0
		name_label.clip_text = true
		name_label.tooltip_text = definition.name_fa
		var amount_label: Label = _make_label("0.0", 13, Color("#f1d37d"))
		var icon_label: Label = _make_label(RESOURCE_ICONS.get(resource_id, "📦"), 20, Color.WHITE)
		icon_label.custom_minimum_size = Vector2(25.0, 26.0)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.pivot_offset = Vector2(12.5, 13.0)
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_label.tooltip_text = definition.name_fa
		labels.add_child(name_label)
		labels.add_child(amount_label)
		chip_row.add_child(labels)
		chip_row.add_child(icon_label)
		chip.add_child(chip_row)
		chips.add_child(chip)
		_inventory_amounts[resource_id] = amount_label
		_inventory_icons[resource_id] = icon_label
	scroll.add_child(chips)
	row.add_child(scroll)
	panel.add_child(row)
	return panel


func _build_action_bar() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	_style_panel(panel, Color("#202d30"), Color("#4c6656"))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for action: Dictionary in [
		{"id": "build", "text": "🏗  ساخت", "callback": _toggle_build_panel, "color": Color("#345644"), "hover": Color("#477658"), "accent": Color("#8bc489")},
		{"id": "shop", "text": "🛍  فروشگاه", "callback": _open_shop_panel, "color": Color("#62502f"), "hover": Color("#806a3c"), "accent": Color("#d7bd75")},
		{"id": "market", "text": "🏪  بازار", "callback": _toggle_market_panel, "color": Color("#2e5559"), "hover": Color("#3c7071"), "accent": Color("#82c3b7")},
		{"id": "progress", "text": "🗺  مسیر تولید", "callback": _toggle_progress_panel, "color": Color("#4e405d"), "hover": Color("#665477"), "accent": Color("#bba1ce")},
	]:
		var button: Button = Button.new()
		button.text = str(action["text"])
		button.custom_minimum_size = Vector2(142.0, 46.0)
		_style_action_button(button, action["color"], action["hover"], action["accent"])
		button.pressed.connect(action["callback"])
		button.pressed.connect(_pulse_button.bind(button))
		row.add_child(button)
		_toolbar_buttons[str(action["id"])] = button
	var cancel_button: Button = Button.new()
	cancel_button.text = "↩  لغو ساخت"
	cancel_button.custom_minimum_size = Vector2(132.0, 46.0)
	_style_action_button(cancel_button, Color("#713d3b"), Color("#914f48"), Color("#dfa096"))
	cancel_button.pressed.connect(_cancel_build_mode)
	cancel_button.pressed.connect(_pulse_button.bind(cancel_button))
	cancel_button.visible = false
	row.add_child(cancel_button)
	_toolbar_buttons["cancel"] = cancel_button
	panel.add_child(row)
	return panel


func _style_action_button(button: Button, base_color: Color, hover_color: Color, accent: Color) -> void:
	for state: Dictionary in [
		{"name": "normal", "color": base_color, "shadow": 3},
		{"name": "hover", "color": hover_color, "shadow": 5},
		{"name": "pressed", "color": base_color.darkened(0.18), "shadow": 1},
		{"name": "disabled", "color": Color("#303a38"), "shadow": 0},
	]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = state["color"]
		style.border_color = accent
		style.set_border_width_all(1)
		style.set_corner_radius_all(14)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		style.content_margin_top = 7.0
		style.content_margin_bottom = 7.0
		style.shadow_color = Color(accent, 0.24)
		style.shadow_size = int(state["shadow"])
		style.shadow_offset = Vector2(0.0, 2.0)
		button.add_theme_stylebox_override(str(state["name"]), style)
	button.add_theme_color_override("font_color", Color("#f1f5df"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#f5e2b5"))
	button.add_theme_font_size_override("font_size", 14)


func _pulse_button(button: Button) -> void:
	_pulse_control(button, 1.08)


func _build_popup_header(title_text: String, close_callback: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title: Label = _make_label(title_text, 17, Color("#eaf1e5"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var close_button: Button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38.0, 34.0)
	close_button.pressed.connect(close_callback)
	row.add_child(close_button)
	return row


func _add_popup_panel(panel: PanelContainer, width: float, height: float, bottom_offset: float = 70.0) -> void:
	panel.custom_minimum_size = Vector2(width, height)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -(height + bottom_offset)
	panel.offset_bottom = -bottom_offset
	panel.pivot_offset = Vector2(width * 0.5, height * 0.5)
	panel.z_index = 11
	panel.visible = false
	_overlay_layer.add_child(panel)


func _build_build_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	_style_panel(panel, Color("#202d30"), Color("#8bb979"))
	_add_popup_panel(panel, 920.0, 340.0)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	body.add_child(_build_popup_header("ساخت", _close_popup))
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_buttons.clear()
	for category: String in BUILDING_CATEGORIES:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var grid: GridContainer = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for definition: BuildingDefinition in _catalog.buildings.values():
			if definition.category != category:
				continue
			var build_button: Button = _make_build_button(definition)
			build_button.custom_minimum_size = Vector2(204.0, 54.0)
			_build_buttons[definition.id] = build_button
			grid.add_child(build_button)
		scroll.add_child(grid)
		tabs.add_child(scroll)
		tabs.set_tab_title(tabs.get_tab_count() - 1, category)
	body.add_child(tabs)
	panel.add_child(body)
	return panel


func _build_shop_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	_style_panel(panel, Color("#202d30"), Color("#d1aa57"))
	_add_popup_panel(panel, 720.0, 440.0)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	body.add_child(_build_popup_header("فروش محصولات", _close_popup))
	_shop_status = _make_label("", 12, Color("#f1d37d"))
	body.add_child(_shop_status)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_shop_controls.clear()
	for resource_id: String in _catalog.resource_ids():
		var definition: ResourceDefinition = _catalog.resources[resource_id]
		var item: HBoxContainer = HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		item.custom_minimum_size.x = 210.0
		var stock_label: Label = _make_label("", 11, Color("#e3eadc"))
		stock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(stock_label)
		var sell_button: Button = Button.new()
		sell_button.text = "فروش"
		sell_button.custom_minimum_size = Vector2(58.0, 32.0)
		sell_button.pressed.connect(_on_shop_sell.bind(resource_id))
		item.add_child(sell_button)
		grid.add_child(item)
		_shop_controls.append({"resource_id": resource_id, "stock_label": stock_label, "sell_button": sell_button, "unit_price": definition.unit_price})
	scroll.add_child(grid)
	body.add_child(scroll)
	panel.add_child(body)
	return panel


func _build_market_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	_style_panel(panel, Color("#202d30"), Color("#6da6a0"))
	_add_popup_panel(panel, 650.0, 470.0)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	body.add_child(_build_popup_header("بازار خودکار", _close_popup))
	_market_summary = _make_label("", 12, Color("#c5d6c0"))
	body.add_child(_market_summary)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	_market_controls.clear()
	for resource_id: String in _catalog.resource_ids():
		var definition: ResourceDefinition = _catalog.resources[resource_id]
		var market_row: HBoxContainer = HBoxContainer.new()
		market_row.add_theme_constant_override("separation", 6)
		var resource_label: Label = _make_label(definition.name_fa, 12, Color("#e3eadc"))
		resource_label.text = "%s  %s" % [RESOURCE_ICONS.get(resource_id, "📦"), definition.name_fa]
		resource_label.custom_minimum_size.x = 150.0
		resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		market_row.add_child(resource_label)
		var toggle: Button = Button.new()
		toggle.toggle_mode = true
		toggle.custom_minimum_size = Vector2(112.0, 32.0)
		toggle.pressed.connect(_on_market_toggle.bind(resource_id, toggle))
		market_row.add_child(toggle)
		var minimum: SpinBox = SpinBox.new()
		minimum.min_value = 0.0
		minimum.max_value = 100000.0
		minimum.step = 1.0
		minimum.prefix = "نگه‌دار "
		minimum.custom_minimum_size.x = 142.0
		minimum.value_changed.connect(_on_market_minimum_changed.bind(resource_id))
		market_row.add_child(minimum)
		list.add_child(market_row)
		_market_controls.append({"resource_id": resource_id, "toggle": toggle, "minimum": minimum})
	scroll.add_child(list)
	body.add_child(scroll)
	panel.add_child(body)
	return panel


func _build_progress_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	_style_panel(panel, Color("#202d30"), Color("#aa945d"))
	_add_popup_panel(panel, 1140.0, 600.0)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	body.add_child(_build_popup_header("نقشهٔ مسیرهای تولید", _close_popup))
	_progress_summary = _make_label("", 13, Color("#d6e5cc"))
	body.add_child(_progress_summary)
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.custom_minimum_size.y = 16.0
	_progress_bar.show_percentage = false
	body.add_child(_progress_bar)
	var route_hint: Label = _make_label("🌳 هر شاخه مسیر کامل یک محصول است، از ریشه (معدن و مزرعه) تا میوه (محصول نهایی). ▸ شاخه را باز و بسته کن و روی هر ردیف بزن تا مسیرش باز یا ساخته شود. کارخانه مشترک در چند شاخه تکرار می‌شود.", 11, Color("#acbbb0"))
	route_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(route_hint)
	_route_buttons.clear()
	_route_state_labels.clear()
	_tree_rows.clear()
	_tree_collapsed.clear()
	_tree_search = ""
	_tree_count_labels.clear()
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	var search_box: LineEdit = LineEdit.new()
	search_box.placeholder_text = "🔍 جستجوی ساختمان یا کالا..."
	search_box.clear_button_enabled = true
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.text_changed.connect(_on_tree_search_changed)
	toolbar.add_child(search_box)
	var expand_all: Button = Button.new()
	expand_all.text = "➕ همه"
	expand_all.tooltip_text = "بازکردن همه شاخه‌ها"
	expand_all.pressed.connect(_on_tree_expand_all.bind(false))
	toolbar.add_child(expand_all)
	var collapse_all: Button = Button.new()
	collapse_all.text = "➖ همه"
	collapse_all.tooltip_text = "بستن همه شاخه‌ها"
	collapse_all.pressed.connect(_on_tree_expand_all.bind(true))
	toolbar.add_child(collapse_all)
	body.add_child(toolbar)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tree_root: VBoxContainer = VBoxContainer.new()
	tree_root.add_theme_constant_override("separation", 2)
	tree_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for chain: Dictionary in TREE_CHAINS:
		var root_building: BuildingDefinition = _producer_for_resource(str(chain["final"]))
		if root_building == null:
			continue
		tree_root.add_child(_build_tree_section_header("%s مسیر %s" % [str(chain["icon"]), str(chain["title"])]))
		_add_tree_row(tree_root, root_building, 0, "chain:" + str(chain["final"]), true)
	var infra: Array[BuildingDefinition] = []
	for definition: BuildingDefinition in _catalog.buildings.values():
		if definition.kind != "producer":
			infra.append(definition)
	infra.sort_custom(func(a: BuildingDefinition, b: BuildingDefinition) -> bool:
		if a.category == b.category:
			return a.name_fa < b.name_fa
		return a.category < b.category)
	tree_root.add_child(_build_tree_section_header("⚙ خدمات و شهرسازی — برق، انبار، بازار، پارک، تزئینات"))
	for definition: BuildingDefinition in infra:
		_add_tree_row(tree_root, definition, 0, "infra:" + definition.id, false)
	scroll.add_child(tree_root)
	body.add_child(scroll)
	_refresh_tree_visibility()
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_expand_button = Button.new()
	_expand_button.pressed.connect(_expand_land)
	_expand_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_expand_button)
	_prestige_button = Button.new()
	_prestige_button.text = "پرستیژ"
	_prestige_button.pressed.connect(_request_prestige)
	_prestige_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_prestige_button)
	body.add_child(buttons)
	panel.add_child(body)
	return panel


func _build_tree_section_header(text_value: String) -> Label:
	var header: Label = _make_label(text_value, 14, Color("#f1d37d"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return header


func _add_tree_row(box: VBoxContainer, definition: BuildingDefinition, depth: int, path: String, is_chain_root: bool) -> void:
	var children: Array[BuildingDefinition] = _child_buildings(definition)
	var is_branch: bool = not children.is_empty()
	var card: PanelContainer = PanelContainer.new()
	var border: Color = Color("#e8c34a") if is_chain_root else Color(definition.color_hex)
	_style_panel(card, Color("#263438"), border)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = _building_tooltip(definition)
	card.gui_input.connect(_on_tree_row_clicked.bind(definition.id))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if depth > 0:
		var indent: Control = Control.new()
		indent.custom_minimum_size = Vector2(float(depth) * 26.0, 0.0)
		indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(indent)
	var fold: Button = Button.new()
	fold.custom_minimum_size = Vector2(30.0, 0.0)
	fold.focus_mode = Control.FOCUS_NONE
	if is_branch:
		fold.text = "▸" if bool(_tree_collapsed.get(path, false)) else "▾"
		fold.tooltip_text = "باز/بسته‌کردن شاخه"
		fold.pressed.connect(_on_tree_fold.bind(path))
	else:
		fold.text = "•"
		fold.disabled = true
	row.add_child(fold)
	var icon_label: Label = _make_label(_tree_row_icon(definition), 20, Color.WHITE)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_label)
	var name_label: Label = _make_label("%s%s" % [definition.name_fa, "  ⭐" if is_chain_root else ""], 13, Color("#e8c34a") if is_chain_root else Color("#edf3e5"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	name_label.tooltip_text = definition.description_fa
	row.add_child(name_label)
	var flow_label: Label = _make_label(_tree_flow_text(definition), 11, Color("#acbbb0"))
	flow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_label.size_flags_stretch_ratio = 2.0
	flow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow_label.clip_text = true
	row.add_child(flow_label)
	var count_label: Label = _make_label("", 11, Color("#8fd0ff"))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count_label)
	var kind_label: Label = _make_label("🔒" if definition.tier > 1 else "✅", 12, Color("#f1d37d"))
	kind_label.tooltip_text = "نیازمند بازکردن مسیر" if definition.tier > 1 else "باز"
	kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(kind_label)
	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(118.0, 34.0)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.pressed.connect(_on_route_action.bind(definition.id))
	row.add_child(action_button)
	card.add_child(row)
	box.add_child(card)
	if not _route_buttons.has(definition.id):
		_route_buttons[definition.id] = []
		_route_state_labels[definition.id] = []
		_tree_count_labels[definition.id] = []
	(_route_buttons[definition.id] as Array).append(action_button)
	(_route_state_labels[definition.id] as Array).append(kind_label)
	(_tree_count_labels[definition.id] as Array).append(count_label)
	var child_keys: Array[String] = []
	for child: BuildingDefinition in children:
		child_keys.append(path + "/" + child.id)
	_tree_rows.append({"panel": card, "fold": fold, "key": path, "parent": _parent_path(path), "children": child_keys, "is_branch": is_branch, "definition_id": definition.id, "search_text": _tree_search_text(definition)})
	for child: BuildingDefinition in children:
		_add_tree_row(box, child, depth + 1, path + "/" + child.id, false)


func _parent_path(path: String) -> String:
	var slash: int = path.rfind("/")
	if slash < 0:
		return ""
	return path.substr(0, slash)


func _tree_flow_text(definition: BuildingDefinition) -> String:
	if definition.kind == "producer" and _catalog.recipes.has(definition.recipe_id):
		var recipe: RecipeDefinition = _catalog.recipes[definition.recipe_id]
		if recipe.inputs.is_empty():
			return "⛏ ماده اولیه  •  ⬇ %s" % _route_goods_text(recipe.outputs)
		return "⬇ %s  •  ⬆ %s" % [_route_goods_text(recipe.outputs), _route_goods_text(recipe.inputs)]
	return _building_route_output(definition)


func _tree_search_text(definition: BuildingDefinition) -> String:
	var parts: Array[String] = [definition.name_fa, definition.category]
	if definition.kind == "producer" and _catalog.recipes.has(definition.recipe_id):
		var recipe: RecipeDefinition = _catalog.recipes[definition.recipe_id]
		var resource_keys: Array = recipe.inputs.keys() + recipe.outputs.keys()
		for res: Variant in resource_keys:
			var resource: ResourceDefinition = _catalog.resources.get(str(res))
			parts.append(resource.name_fa if resource != null else str(res))
	else:
		parts.append(_building_route_output(definition))
	return " ".join(parts).to_lower()


func _child_buildings(definition: BuildingDefinition) -> Array[BuildingDefinition]:
	var result: Array[BuildingDefinition] = []
	if definition.kind != "producer" or not _catalog.recipes.has(definition.recipe_id):
		return result
	var seen: Dictionary = {}
	for input_id: Variant in _catalog.recipes[definition.recipe_id].inputs.keys():
		var producer: BuildingDefinition = _producer_for_resource(str(input_id))
		if producer == null or seen.has(producer.id):
			continue
		seen[producer.id] = true
		result.append(producer)
	result.sort_custom(func(a: BuildingDefinition, b: BuildingDefinition) -> bool: return a.name_fa < b.name_fa)
	return result


func _on_tree_row_clicked(event: InputEvent, definition_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_on_route_action(definition_id)


func _on_tree_fold(path: String) -> void:
	if bool(_tree_collapsed.get(path, false)):
		_tree_collapsed.erase(path)
	else:
		_tree_collapsed[path] = true
	_refresh_tree_visibility()


func _on_tree_expand_all(collapse: bool) -> void:
	if collapse:
		for row: Dictionary in _tree_rows:
			if bool(row["is_branch"]):
				_tree_collapsed[str(row["key"])] = true
	else:
		_tree_collapsed.clear()
	_refresh_tree_visibility()


func _on_tree_search_changed(new_text: String) -> void:
	_tree_search = new_text.strip_edges().to_lower()
	_refresh_tree_visibility()


func _refresh_tree_visibility() -> void:
	var by_key: Dictionary = {}
	for row: Dictionary in _tree_rows:
		by_key[str(row["key"])] = row
	var memo: Dictionary = {}
	for row: Dictionary in _tree_rows:
		var panel: PanelContainer = row["panel"] as PanelContainer
		if panel == null:
			continue
		var show: bool = true
		if _tree_search.is_empty():
			show = not _has_collapsed_ancestor(str(row["key"]), by_key)
		else:
			show = _row_matches_search(row, memo, by_key)
		panel.visible = show
		if bool(row["is_branch"]):
			var fold_button: Button = row["fold"] as Button
			if fold_button != null:
				fold_button.text = "▸" if bool(_tree_collapsed.get(str(row["key"]), false)) else "▾"


func _has_collapsed_ancestor(key: String, by_key: Dictionary) -> bool:
	var parent: String = _parent_path(key)
	while not parent.is_empty():
		if bool(_tree_collapsed.get(parent, false)):
			return true
		if not by_key.has(parent):
			break
		parent = _parent_path(parent)
	return false


func _row_matches_search(row: Dictionary, memo: Dictionary, by_key: Dictionary) -> bool:
	var key: String = str(row["key"])
	if memo.has(key):
		return bool(memo[key])
	var matched: bool = str(row["search_text"]).contains(_tree_search)
	if not matched:
		var child_keys: Array = row["children"] as Array
		for child_key: Variant in child_keys:
			var child: Dictionary = by_key.get(str(child_key), {}) as Dictionary
			if child.is_empty():
				continue
			if _row_matches_search(child, memo, by_key):
				matched = true
				break
	memo[key] = matched
	return matched


func _primary_tree_output(definition: BuildingDefinition) -> String:
	if definition.kind == "producer" and _catalog.recipes.has(definition.recipe_id):
		var outs: Array = _catalog.recipes[definition.recipe_id].outputs.keys()
		if not outs.is_empty():
			return str(outs[0])
	return ""


func _tree_row_icon(definition: BuildingDefinition) -> String:
	if definition.kind == "decoration":
		if definition.id == "house":
			return "🏠"
		return "🌲"
	return RESOURCE_ICONS.get(_primary_tree_output(definition), "🏭")


func _producer_for_resource(resource_id: String) -> BuildingDefinition:
	var best: BuildingDefinition = null
	for definition: BuildingDefinition in _catalog.buildings.values():
		if definition.kind != "producer" or not _catalog.recipes.has(definition.recipe_id):
			continue
		if not _catalog.recipes[definition.recipe_id].outputs.has(resource_id):
			continue
		if best == null or definition.tier < best.tier or (definition.tier == best.tier and definition.build_cost < best.build_cost):
			best = definition
	return best


func _route_goods_text(amounts: Dictionary) -> String:
	var parts: Array[String] = []
	var resource_ids: Array[String] = []
	for key: Variant in amounts.keys():
		resource_ids.append(str(key))
	resource_ids.sort()
	for resource_id: String in resource_ids:
		if not _catalog.resources.has(resource_id):
			continue
		var resource: ResourceDefinition = _catalog.resources[resource_id]
		parts.append("%s %s ×%s" % [RESOURCE_ICONS.get(resource_id, "📦"), resource.name_fa, String.num(float(amounts[resource_id]), 2)])
	return " + ".join(parts)


func _building_route_output(definition: BuildingDefinition) -> String:
	match definition.kind:
		"power":
			return "شبکه\n⚡ +%s/s" % String.num(definition.power_output_per_second, 1)
		"battery":
			return "شبکه\n🔋 %s واحد" % _format_amount(definition.battery_capacity)
		"storage":
			return "انبار\n📦 +%s" % _format_amount(definition.storage_capacity)
		"market":
			return "بازار\n🛒 فروش آنی"
		"shop":
			return "فروش\n🛍 دستی"
		"park":
			return "همسایه\n🌳 +۱۲٪"
		"decoration":
			return "شهرسازی\n🏡 تزئینی"
	return definition.description_fa


func _on_route_action(building_id: String) -> void:
	if not _catalog.buildings.has(building_id):
		return
	var definition: BuildingDefinition = _catalog.buildings[building_id]
	if _simulation.is_building_unlocked(building_id):
		_select_building(building_id)
		return
	_simulation.enqueue_command(GameCommand.unlock_building(building_id))
	_notice = "درخواست بازکردن مسیر %s ثبت شد." % definition.name_fa


func _build_inspector_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	_style_panel(panel, Color("#202d30"), Color("#d1aa57"))
	panel.custom_minimum_size = Vector2(430.0, 138.0)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -444.0
	panel.offset_right = -12.0
	panel.offset_top = 130.0
	panel.offset_bottom = 268.0
	panel.z_index = 9
	panel.visible = false
	panel.pivot_offset = Vector2(215.0, 69.0)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	_selection_title = _make_label("", 15, Color("#f1d37d"))
	body.add_child(_selection_title)
	_selection_info = _make_label("", 11, Color("#d2ddd0"))
	_selection_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_selection_info)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	_upgrade_button = Button.new()
	_upgrade_button.text = "ارتقا"
	_upgrade_button.pressed.connect(_upgrade_selected)
	_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_upgrade_button)
	_demolish_button = Button.new()
	_demolish_button.text = "حذف"
	_demolish_button.pressed.connect(_request_demolition)
	buttons.add_child(_demolish_button)
	body.add_child(buttons)
	panel.add_child(body)
	_overlay_layer.add_child(panel)
	return panel


func _style_panel(control: Control, background: Color, border: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	control.add_theme_stylebox_override("panel", style)


func _make_build_button(definition: BuildingDefinition) -> Button:
	var button: Button = Button.new()
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.text = "%s  •  $%d" % [definition.name_fa, int(definition.build_cost)]
	button.toggle_mode = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sprite_path: String = _building_icon_path(definition.id, 1)
	if FileAccess.file_exists(sprite_path):
		button.icon = load(sprite_path) as Texture2D
	button.custom_minimum_size.y = 40.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.tooltip_text = _building_tooltip(definition)
	button.text_direction = Control.TEXT_DIRECTION_AUTO
	button.pressed.connect(_select_building.bind(definition.id))
	return button


func _building_icon_path(definition_id: String, level: int) -> String:
	var leveled: String = "res://assets/sprites/%s_%d.svg" % [definition_id, level]
	if FileAccess.file_exists(leveled):
		return leveled
	var base_svg: String = "res://assets/sprites/%s.svg" % definition_id
	if FileAccess.file_exists(base_svg):
		return base_svg
	return "res://assets/sprites/%s.png" % definition_id


func _building_tooltip(definition: BuildingDefinition) -> String:
	var lines: Array[String] = [definition.description_fa]
	if definition.kind == "producer" and _catalog.recipes.has(definition.recipe_id):
		var recipe: RecipeDefinition = _catalog.recipes[definition.recipe_id]
		if not recipe.inputs.is_empty():
			lines.append("ورودی: %s" % _format_goods(recipe.inputs))
		lines.append("خروجی: %s — %s/ثانیه" % [_format_goods(recipe.outputs), String.num(recipe.output_per_second, 2)])
	if definition.tier > 1:
		lines.append("بازکردن مسیر: $%s" % _format_money(definition.unlock_cost))
	return "\n".join(lines)


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_direction = Control.TEXT_DIRECTION_AUTO
	return label


func _show_boot_error() -> void:
	var error_box: VBoxContainer = VBoxContainer.new()
	error_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	error_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(error_box)
	error_box.add_child(_make_label("داده‌های بازی قابل بارگذاری نیستند", 22, Color("#ff988c")))
	for message: String in _catalog.errors:
		var error_line: Label = _make_label(message, 14, Color("#f1d9d5"))
		error_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_box.add_child(error_line)


func _refresh_ui() -> void:
	if _simulation.catalog == null or _header_money == null:
		return
	var snapshot: Dictionary = _simulation.get_snapshot()
	var money_text: String = "$%s" % _format_money(float(snapshot["money"]))
	if _header_money.text != money_text:
		_header_money.text = money_text
		_pulse_control(_header_money, 1.08)
	var income_text: String = "+$%s/s" % String.num(float(snapshot["income_per_second"]), 2)
	if _header_income.text != income_text:
		_header_income.text = income_text
		_pulse_control(_header_income, 1.08)
	var storage_text: String = "%s/%s" % [_format_amount(float(snapshot["storage_used"])), _format_amount(float(snapshot["storage_capacity"]))]
	if _header_storage.text != storage_text:
		_header_storage.text = storage_text
		_pulse_control(_header_storage, 1.06)
	var power_ratio_value: float = float(snapshot["power_ratio"])
	var power_demand: float = float(snapshot["power_demand_per_second"])
	var power_output: float = float(snapshot["power_generated_per_second"])
	var power_percent: int = int(round(power_ratio_value * 100.0))
	var power_text: String = "⚡ %d%%" % power_percent if power_demand > 0.0 else "⚡ آماده"
	if _header_power.text != power_text:
		_header_power.text = power_text
		_pulse_control(_header_power, 1.08)
	_header_power.add_theme_color_override("font_color", Color("#ff9a82") if bool(snapshot["power_shortage"]) else Color("#a8d89f"))
	_header_power.tooltip_text = "تولید %s • مصرف %s واحد/ثانیه • باتری %s/%s" % [String.num(power_output, 2), String.num(power_demand, 2), _format_amount(float(snapshot["battery_energy_stored"])), _format_amount(float(snapshot["battery_energy_capacity"]))]
	var inventory: Dictionary = snapshot["inventory"]
	for resource_id: String in _inventory_amounts:
		var amount_label: Label = _inventory_amounts[resource_id]
		var next_amount: String = _format_amount(float(inventory.get(resource_id, 0.0)))
		if amount_label.text != next_amount:
			amount_label.text = next_amount
			_pulse_control(_inventory_icons[resource_id], 1.2)
	var storage_ratio: float = float(snapshot["storage_used"]) / maxf(float(snapshot["storage_capacity"]), 1.0)
	_header_storage.add_theme_color_override("font_color", Color("#ff9a82") if storage_ratio >= 0.9 else Color("#d3e0d0"))
	if _notice != _last_displayed_notice and not _notice.is_empty():
		_show_notice(_notice)
	for definition_id: String in _build_buttons:
		_build_buttons[definition_id].button_pressed = _build_mode_id == definition_id
		var definition: BuildingDefinition = _catalog.buildings[definition_id]
		var unlocked: bool = _simulation.is_building_unlocked(definition_id)
		_build_buttons[definition_id].disabled = not unlocked
		_build_buttons[definition_id].text = "%s  •  $%d%s" % [definition.name_fa, int(definition.build_cost), "  🔒" if not unlocked else ""]
		if not unlocked:
			_build_buttons[definition_id].tooltip_text = "%s\nبرای ساخت، ابتدا مسیر را در نقشه با $%s باز کن." % [_building_tooltip(definition), _format_money(definition.unlock_cost)]
		else:
			_build_buttons[definition_id].tooltip_text = _building_tooltip(definition)
	var built_counts: Dictionary = {}
	for row_building: Dictionary in snapshot["buildings"]:
		var built_id: String = str(row_building.get("definition_id", ""))
		built_counts[built_id] = int(built_counts.get(built_id, 0)) + 1
	for definition_id: String in _route_buttons:
		var definition: BuildingDefinition = _catalog.buildings[definition_id]
		var unlocked: bool = _simulation.is_building_unlocked(definition_id)
		var built_count: int = int(built_counts.get(definition_id, 0))
		for count_label: Label in (_tree_count_labels.get(definition_id, []) as Array):
			count_label.text = ("×%d" % built_count) if built_count > 0 else ""
		var state_text: String = "✅ باز" if unlocked else "🔐 قفل"
		for route_state: Label in (_route_state_labels.get(definition_id, []) as Array):
			route_state.text = state_text
		var action_text: String = ""
		var action_disabled: bool = false
		var action_tip: String = ""
		if unlocked:
			action_text = "🏗 ساخت • $%s" % _format_money(definition.build_cost)
			action_tip = definition.description_fa
		else:
			action_text = "🔓 مسیر • $%s" % _format_money(definition.unlock_cost)
			action_disabled = float(snapshot["money"]) < definition.unlock_cost
			if action_disabled:
				action_tip = "پول کافی نیست؛ برای بازکردن مسیر $%s لازم است." % _format_money(definition.unlock_cost)
			else:
				action_tip = definition.description_fa
		for route_button: Button in (_route_buttons[definition_id] as Array):
			route_button.text = action_text
			route_button.disabled = action_disabled
			route_button.tooltip_text = action_tip
	var buildings: Array[Dictionary] = snapshot["buildings"]
	var preview_cost: float = 0.0
	if _catalog.buildings.has(_build_mode_id):
		preview_cost = _catalog.buildings[_build_mode_id].build_cost
	_grid.set_game_view(int(snapshot["land_size"]), buildings, _build_mode_id, _selected_building_id, float(snapshot["money"]), preview_cost)
	_toolbar_buttons["cancel"].visible = not _build_mode_id.is_empty()
	_toolbar_buttons["market"].disabled = int(snapshot["market_count"]) <= 0
	_toolbar_buttons["shop"].disabled = int(snapshot["shop_count"]) <= 0
	_update_progression(snapshot)
	_update_inspector(buildings)
	_update_shop_controls(snapshot)
	_update_market_controls(snapshot)


func _pulse_control(control: Control, peak_scale: float = 1.14) -> void:
	if not is_instance_valid(control):
		return
	if _pulse_tweens.has(control):
		var active_tween: Tween = _pulse_tweens[control]
		if active_tween != null and active_tween.is_running():
			return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.94, 0.94)
	var pulse: Tween = create_tween()
	_pulse_tweens[control] = pulse
	pulse.tween_property(control, "scale", Vector2(peak_scale, peak_scale), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(control, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulse.finished.connect(func() -> void: _pulse_tweens.erase(control))


func _show_notice(message: String) -> void:
	_last_displayed_notice = message
	_notice_label.text = message
	_notice_panel.visible = true
	_notice_panel.modulate.a = 0.0
	if _notice_tween != null and _notice_tween.is_running():
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice_panel, "modulate:a", 1.0, 0.16)
	_notice_tween.tween_interval(2.0)
	_notice_tween.tween_property(_notice_panel, "modulate:a", 0.0, 0.28)
	_notice_tween.tween_callback(func() -> void: _notice_panel.visible = false)


func _update_inspector(buildings: Array[Dictionary]) -> void:
	var selected: Dictionary = {}
	for row: Dictionary in buildings:
		if int(row["id"]) == _selected_building_id:
			selected = row
			break
	if selected.is_empty():
		_selected_building_id = 0
		_inspector_panel.visible = false
		return
	_selection_title.text = "%s  •  Lv.%d/%d  •  %s" % [str(selected["name_fa"]), int(selected["level"]), int(selected["max_level"]), _status_label(str(selected["status"]))]
	var lines: Array[String] = []
	var inputs: Dictionary = selected["recipe_inputs"]
	var outputs: Dictionary = selected["recipe_outputs"]
	if not inputs.is_empty():
		lines.append("ورودی %s" % _format_goods(inputs))
	if not outputs.is_empty():
		lines.append("تولید %s/ثانیه" % _format_goods(outputs))
	if str(selected["kind"]) == "storage":
		lines.append("+%s ظرفیت انبار" % _format_amount(float(selected["storage_capacity"])))
	if str(selected["kind"]) == "market":
		lines.append("فروش آنی مازاد بر حداقل نگه‌داری")
	if float(selected["power_demand_per_second"]) > 0.0:
		lines.append("−⚡ %s/s" % String.num(float(selected["power_demand_per_second"]), 2))
	if str(selected["kind"]) == "power":
		lines.append("+⚡ %s/s" % String.num(float(selected["power_output_per_second"]), 2))
	if str(selected["kind"]) == "battery":
		lines.append("باتری %s/%s" % [_format_amount(float(selected["battery_energy"])), _format_amount(float(selected["battery_capacity"]))])
	var neighbor_bonus: float = float(selected.get("neighbor_bonus", 0.0))
	if neighbor_bonus > 0.0:
		lines.append("همسایگی +%d%%" % int(round(neighbor_bonus * 100.0)))
	_selection_info.text = "  •  ".join(lines) if not lines.is_empty() else str(selected["description_fa"])
	var details: Array[String] = [str(selected["description_fa"]), "وضعیت: %s" % _status_label(str(selected["status"]))]
	if not inputs.is_empty():
		details.append("ورودی: %s" % _format_goods(inputs))
	if not outputs.is_empty():
		details.append("خروجی: %s" % _format_goods(outputs))
	if not str(selected["fuel_resource_id"]).is_empty() and _catalog.resources.has(str(selected["fuel_resource_id"])):
		details.append("سوخت: %s" % _catalog.resources[str(selected["fuel_resource_id"])].name_fa)
	_selection_info.tooltip_text = "\n".join(details)
	var inspector_was_hidden: bool = not _inspector_panel.visible
	_inspector_panel.visible = true
	if inspector_was_hidden:
		_inspector_panel.modulate.a = 0.0
		_inspector_panel.scale = Vector2(0.96, 0.96)
		if _inspector_tween != null and _inspector_tween.is_running():
			_inspector_tween.kill()
		_inspector_tween = create_tween().set_parallel(true)
		_inspector_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_inspector_tween.tween_property(_inspector_panel, "modulate:a", 1.0, 0.16)
		_inspector_tween.tween_property(_inspector_panel, "scale", Vector2.ONE, 0.22)
	_upgrade_button.disabled = int(selected["upgrade_cost"]) <= 0 or float(_simulation.state.money) < float(selected["upgrade_cost"])
	if int(selected["upgrade_cost"]) > 0:
		_upgrade_button.text = "ارتقا  •  $%d" % int(selected["upgrade_cost"])
	else:
		_upgrade_button.text = "بالاترین سطح"
		_upgrade_button.disabled = true
	_demolish_button.text = "حذف  •  +$%s" % _format_money(float(selected["refund"]))


func _update_shop_controls(snapshot: Dictionary) -> void:
	var inventory: Dictionary = snapshot["inventory"]
	var market_rules: Dictionary = snapshot["market_rules"]
	var has_stock: bool = false
	var auto_sell_enabled: bool = false
	for row: Dictionary in _shop_controls:
		var resource_id: String = str(row["resource_id"])
		var quantity: float = float(inventory.get(resource_id, 0.0))
		var resource: ResourceDefinition = _catalog.resources[resource_id]
		var rule: Dictionary = market_rules.get(resource_id, {})
		if bool(rule.get("enabled", false)) and int(snapshot["market_count"]) > 0:
			auto_sell_enabled = true
		var stock_label: Label = row["stock_label"]
		stock_label.text = "%s %s\n%s" % [RESOURCE_ICONS.get(resource_id, "📦"), resource.name_fa, _format_amount(quantity)]
		var sell_button: Button = row["sell_button"]
		sell_button.disabled = quantity <= 0.000001
		sell_button.tooltip_text = "موجودی صفر است" if quantity <= 0.000001 else "فروش %s × $%s؛ دریافت $%s%s" % [_format_amount(quantity), String.num(resource.unit_price, 2), _format_money(quantity * resource.unit_price), " • فروش خودکار هم روشن است" if bool(rule.get("enabled", false)) and int(snapshot["market_count"]) > 0 else ""]
		has_stock = has_stock or quantity > 0.000001
	_shop_status.text = "موجودی آمادهٔ فروش" if has_stock else "انبار خالی"
	if auto_sell_enabled:
		_shop_status.text += "  •  بازار خودکار روشن"


func _update_market_controls(snapshot: Dictionary) -> void:
	var market_count: int = int(snapshot["market_count"])
	_market_summary.text = "%d بازار  •  فروش آنی مازاد بر حداقل نگه‌داری" % market_count
	var rules: Dictionary = snapshot["market_rules"]
	for row: Dictionary in _market_controls:
		var resource_id: String = str(row["resource_id"])
		var rule: Dictionary = rules.get(resource_id, {})
		var toggle: Button = row["toggle"]
		var enabled: bool = bool(rule.get("enabled", false))
		toggle.button_pressed = enabled
		toggle.text = "روشن" if enabled else "خاموش"
		var minimum: SpinBox = row["minimum"]
		minimum.set_value_no_signal(float(rule.get("minimum_stock", 0.0)))


func _select_building(definition_id: String) -> void:
	if not _catalog.buildings.has(definition_id):
		_notice = "این ساختمان در داده‌های بازی وجود ندارد."
		_refresh_ui()
		return
	var definition: BuildingDefinition = _catalog.buildings[definition_id]
	if not _simulation.is_building_unlocked(definition_id):
		_notice = "ابتدا مسیر این ساختمان را از نقشهٔ مسیر تولید با پرداخت هزینه باز کن."
		_refresh_ui()
		return
	_close_popup()
	_build_mode_id = definition_id
	_selected_building_id = 0
	_notice = "%s را روی زمین بگذار." % _catalog.buildings[definition_id].name_fa
	_refresh_ui()


func _on_grid_cell_clicked(cell: Vector2i) -> void:
	var existing: BuildingInstance = _simulation.find_building_at(cell)
	if not _build_mode_id.is_empty():
		if existing != null:
			_build_mode_id = ""
			_selected_building_id = existing.id
			_notice = "ساختمان انتخاب شد."
			_refresh_ui()
			_open_context_panel(existing)
		else:
			_simulation.enqueue_command(GameCommand.build(_build_mode_id, cell))
		return
	if existing != null:
		_selected_building_id = existing.id
		_notice = "ساختمان انتخاب شد."
	else:
		_selected_building_id = 0
		_notice = "خانهٔ خالی انتخاب شد."
	_refresh_ui()
	if existing != null:
		_open_context_panel(existing)


func _open_context_panel(building: BuildingInstance) -> void:
	var definition: BuildingDefinition = _catalog.buildings.get(building.definition_id)
	if definition == null:
		return
	if definition.kind == "shop":
		_toggle_popup(_shop_panel)
	elif definition.kind == "market":
		_toggle_popup(_market_panel)


func _upgrade_selected() -> void:
	if _selected_building_id > 0:
		_simulation.enqueue_command(GameCommand.upgrade(_selected_building_id))


func _request_demolition() -> void:
	var building: BuildingInstance = _simulation.find_building(_selected_building_id)
	if building == null:
		return
	var definition: BuildingDefinition = _catalog.buildings[building.definition_id]
	_confirmation_dialog.dialog_text = "«%s» حذف شود؟ بازپرداخت: $%s. منابع انبار باقی می‌مانند." % [definition.name_fa, _format_money(_simulation.get_demolition_refund(building))]
	_confirmation_dialog.popup_centered(Vector2i(420, 150))


func _confirm_demolition() -> void:
	if _selected_building_id > 0:
		_simulation.enqueue_command(GameCommand.demolish(_selected_building_id))
		_selected_building_id = 0


func _on_market_toggle(resource_id: String, button: Button) -> void:
	var current_rule: Dictionary = _simulation.state.market_rules.get(resource_id, {})
	_simulation.enqueue_command(GameCommand.set_market_rule(resource_id, button.button_pressed, float(current_rule.get("minimum_stock", 0.0))))


func _on_market_minimum_changed(value: float, resource_id: String) -> void:
	var current_rule: Dictionary = _simulation.state.market_rules.get(resource_id, {})
	_simulation.enqueue_command(GameCommand.set_market_rule(resource_id, bool(current_rule.get("enabled", false)), value))


func _on_shop_sell(resource_id: String) -> void:
	_simulation.enqueue_command(GameCommand.sell_resource(resource_id))


func _expand_land() -> void:
	_simulation.enqueue_command(GameCommand.expand_land())


func _request_prestige() -> void:
	if _simulation.state.cumulative_revenue + 0.000001 < _simulation.get_prestige_requirement():
		_notice = "برای پرستیژ هنوز درآمد تجمعی کافی نیست."
		_refresh_ui()
		return
	var points_after: int = _simulation.state.prestige_points + 1
	var bonus_after: float = minf(float(points_after) * _catalog.balance.prestige_bonus_per_point, _catalog.balance.prestige_bonus_cap)
	_prestige_dialog.dialog_text = "پرستیژ انجام شود؟ پول فعلی، ساختمان‌ها، موجودی و زمین گسترش‌یافته بازنشانی می‌شوند. درآمد و تولید تجمعی، تنظیم صدا و امتیازهای پرستیژ می‌مانند.\n\nپاداش دائمی تولید: %d%% → %d%%" % [int(round(_simulation.get_snapshot()["prestige_bonus"] * 100.0)), int(round(bonus_after * 100.0))]
	_prestige_dialog.popup_centered(Vector2i(540, 240))


func _confirm_prestige() -> void:
	_simulation.enqueue_command(GameCommand.prestige())
	_selected_building_id = 0
	_build_mode_id = ""


func _update_progression(snapshot: Dictionary) -> void:
	var revenue: float = float(snapshot["cumulative_revenue"])
	var production: float = float(snapshot["cumulative_production"])
	var current_tier: int = int(snapshot["current_tier"])
	var next_revenue_goal: float = _catalog.balance.tier_two_revenue if current_tier < 2 else _catalog.balance.tier_three_revenue
	var next_production_goal: float = _catalog.balance.tier_two_production if current_tier < 2 else _catalog.balance.tier_three_production
	if current_tier >= 3:
		_progress_summary.text = "Tier 3 در دسترس است • مسیر هر ساختمان را جداگانه باز کن و سپس هزینهٔ ساخت را بپرداز."
		_animate_progress_to(100.0)
	else:
		var revenue_progress: float = clampf(revenue / maxf(next_revenue_goal, 1.0), 0.0, 1.0)
		var production_progress: float = clampf(production / maxf(next_production_goal, 1.0), 0.0, 1.0)
		_progress_summary.text = "Tier %d در دسترس  →  Tier %d   •   درآمد %d%%   •   تولید %d%%" % [current_tier, current_tier + 1, int(round(revenue_progress * 100.0)), int(round(production_progress * 100.0))]
		_animate_progress_to(maxf(revenue_progress, production_progress) * 100.0)
	var expansion: Dictionary = _simulation.get_next_expansion()
	if expansion.is_empty():
		_expand_button.text = "زمین %d×%d" % [int(snapshot["land_size"]), int(snapshot["land_size"])]
		_expand_button.disabled = true
		_expand_button.tooltip_text = "بیشترین اندازهٔ زمین باز شده است."
	else:
		var target_size: int = int(expansion["size"])
		var cost: float = float(expansion["cost"])
		var required_revenue: float = float(expansion["revenue"])
		_expand_button.text = "زمین %d×%d  •  $%s" % [target_size, target_size, _format_money(cost)]
		_expand_button.disabled = float(snapshot["money"]) < cost or revenue < required_revenue
		_expand_button.tooltip_text = "درآمد تجمعی لازم: $%s" % _format_money(required_revenue)
	var prestige_requirement: float = float(snapshot["prestige_requirement"])
	_prestige_button.text = "پرستیژ  •  +%d%%" % int(round(float(snapshot["prestige_bonus"]) * 100.0))
	_prestige_button.disabled = revenue < prestige_requirement
	_prestige_button.tooltip_text = "هدف درآمد تجمعی: $%s. بازنشانی شهرک می‌دهد و پاداش دائمی تولید را افزایش می‌دهد." % _format_money(prestige_requirement)
	_sound_toggle.set_pressed_no_signal(bool(snapshot["sound_enabled"]))
	_fullscreen_button.text = "پنجره‌ای" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "تمام‌صفحه"
	_fullscreen_button.tooltip_text = "تغییر حالت نمایش (F11 یا Alt+Enter)"
	_toolbar_buttons["shop"].tooltip_text = "%d فروشگاه ساخته شده" % int(snapshot["shop_count"])
	_toolbar_buttons["market"].tooltip_text = "%d بازار ساخته شده" % int(snapshot["market_count"])


func _animate_progress_to(target_value: float) -> void:
	if is_equal_approx(_progress_target, target_value):
		return
	_progress_target = target_value
	if _progress_tween != null and _progress_tween.is_running():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_property(_progress_bar, "value", target_value, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _toggle_build_panel() -> void:
	_toggle_popup(_build_panel)


func _toggle_market_panel() -> void:
	if _simulation.get_snapshot()["market_count"] <= 0:
		_notice = "اول یک بازار بساز."
		_refresh_ui()
		return
	_toggle_popup(_market_panel)


func _toggle_progress_panel() -> void:
	_toggle_popup(_progress_panel)


func _open_shop_panel() -> void:
	if _simulation.get_snapshot()["shop_count"] <= 0:
		_notice = "اول فروشگاه بساز."
		_refresh_ui()
		return
	_toggle_popup(_shop_panel)


func _toggle_popup(panel: Control) -> void:
	if _active_popup == panel:
		_close_popup()
		return
	if _popup_tween != null and _popup_tween.is_running():
		_popup_tween.kill()
	if _active_popup != null:
		_active_popup.visible = false
	_active_popup = panel
	_popup_backdrop.visible = true
	panel.visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	_popup_tween = create_tween().set_parallel(true)
	_popup_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	_popup_tween.tween_property(panel, "scale", Vector2.ONE, 0.22)


func _close_popup() -> void:
	if _active_popup == null:
		return
	var closing_panel: Control = _active_popup
	_active_popup = null
	_popup_backdrop.visible = false
	if _popup_tween != null and _popup_tween.is_running():
		_popup_tween.kill()
	_popup_tween = create_tween().set_parallel(true)
	_popup_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(closing_panel, "modulate:a", 0.0, 0.12)
	_popup_tween.tween_property(closing_panel, "scale", Vector2(0.98, 0.98), 0.12)
	_popup_tween.chain().tween_callback(func() -> void:
		if _active_popup != closing_panel:
			closing_panel.visible = false
	)


func _on_popup_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_close_popup()
			_popup_backdrop.accept_event()


func _cancel_build_mode() -> void:
	_build_mode_id = ""
	_notice = "ساخت لغو شد."
	_refresh_ui()


func _on_speed_selected(index: int) -> void:
	if index >= 0 and index < SPEEDS.size():
		_speed = SPEEDS[index]
		_simulation_accumulator = 0.0
		_notice = "شبیه‌سازی متوقف شد؛ فرمان‌های ساخت و رابط همچنان کار می‌کنند." if _speed == 0.0 else "سرعت شبیه‌سازی: ×%s" % String.num(_speed, 0)


func _on_sound_toggled(enabled: bool) -> void:
	_simulation.state.sound_enabled = enabled
	_save_game(true)
	if enabled:
		_play_ui_sound()


func _toggle_fullscreen() -> void:
	var is_fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if _fullscreen_button != null:
		_fullscreen_button.text = "پنجره‌ای" if not is_fullscreen else "تمام‌صفحه"


func _make_ui_sound() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count: int = 1764
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(sample_count * 2)
	for index: int in range(sample_count):
		var envelope: float = 1.0 - float(index) / float(sample_count)
		var wave: float = sin(TAU * 660.0 * float(index) / float(stream.mix_rate))
		var sample: int = int(round(wave * envelope * 5200.0))
		samples[index * 2] = sample & 255
		samples[index * 2 + 1] = (sample >> 8) & 255
	stream.data = samples
	return stream


func _play_ui_sound() -> void:
	if _audio_player != null and _simulation.state.sound_enabled:
		_audio_player.play()


func _save_game(automatic: bool = false) -> void:
	if not _saving_enabled or _simulation.catalog == null:
		return
	var result: Dictionary = _save_service.save_state(_simulation.state)
	if not automatic:
		_notice = str(result.get("message", "ذخیره انجام نشد."))
	if not bool(result.get("ok", false)):
		push_warning(str(result.get("message", "ذخیره انجام نشد.")))
	_refresh_ui()


func _format_money(value: float) -> String:
	return "%d" % int(floor(value))


func _format_amount(value: float) -> String:
	return String.num(value, 1)


func _format_goods(amounts: Dictionary) -> String:
	var parts: Array[String] = []
	var keys: Array[String] = []
	for key: Variant in amounts.keys():
		keys.append(str(key))
	keys.sort()
	for resource_id: String in keys:
		var definition: ResourceDefinition = _catalog.resources.get(resource_id)
		var name: String = definition.name_fa if definition != null else resource_id
		parts.append("%s %s" % [name, String.num(float(amounts[resource_id]), 2)])
	return "، ".join(parts)


func _status_label(status: String) -> String:
	match status:
		"operational":
			return "در حال کار"
		"no_input":
			return "ورودی کافی نیست"
		"limited_input":
			return "ورودی کم است؛ تولید محدود شده"
		"storage_full":
			return "انبار پر است؛ تولید متوقف شده"
		"power_limited":
			return "برق کم است؛ تولید متناسب کاهش یافته"
		"power_shortage":
			return "برق کافی نیست؛ تولید متوقف شده"
		"out_of_fuel":
			return "سوخت تمام شده"
		"charging":
			return "باتری در حال شارژ است"
		"discharging":
			return "باتری در حال تخلیه است"
		"standby":
			return "آماده‌به‌کار"
		_:
			return "آماده"
