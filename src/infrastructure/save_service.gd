class_name SaveService
extends RefCounted

const SAVE_VERSION: int = 4
const DEFAULT_PATH: String = "user://industrial_frontier_save.json"


func save_state(state: GameState, path: String = DEFAULT_PATH) -> Dictionary:
	var save_data: Dictionary = {
		"save_version": SAVE_VERSION,
		"saved_unix_time": int(Time.get_unix_time_from_system()),
		"money": state.money,
		"land_size": state.land_size,
		"initial_storage_capacity": state.initial_storage_capacity,
		"inventory": state.inventory,
		"market_rules": state.market_rules,
		"unlocked_buildings": state.unlocked_buildings,
		"next_building_id": state.next_building_id,
		"simulated_seconds": state.simulated_seconds,
		"cumulative_revenue": state.cumulative_revenue,
		"cumulative_production": state.cumulative_production,
		"prestige_points": state.prestige_points,
		"prestige_count": state.prestige_count,
		"sound_enabled": state.sound_enabled,
		"buildings": []
	}
	var sorted_buildings: Array[BuildingInstance] = state.buildings.duplicate()
	sorted_buildings.sort_custom(func(left: BuildingInstance, right: BuildingInstance) -> bool: return left.id < right.id)
	var building_rows: Array[Dictionary] = []
	for building: BuildingInstance in sorted_buildings:
		building_rows.append({
			"id": building.id,
			"definition_id": building.definition_id,
			"x": building.cell.x,
			"y": building.cell.y,
			"level": building.level,
			"energy_stored": building.energy_stored
		})
	save_data["buildings"] = building_rows
	var destination: String = ProjectSettings.globalize_path(path)
	var temporary: String = destination + ".tmp"
	var backup: String = destination + ".bak"
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if directory_error != Error.OK and directory_error != Error.ERR_ALREADY_EXISTS:
		return {"ok": false, "message": "پوشهٔ ذخیره ساخته نشد: %s" % error_string(directory_error)}
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "فایل موقت ذخیره ساخته نشد: %s" % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != Error.OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return {"ok": false, "message": "نوشتن فایل ذخیره کامل نشد: %s" % error_string(write_error)}
	var has_previous: bool = FileAccess.file_exists(path)
	if has_previous:
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		var backup_error: Error = DirAccess.rename_absolute(destination, ProjectSettings.globalize_path(backup))
		if backup_error != Error.OK:
			DirAccess.remove_absolute(temporary)
			return {"ok": false, "message": "نسخهٔ پشتیبان ذخیره نشد: %s" % error_string(backup_error)}
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), destination)
	if rename_error != Error.OK:
		if has_previous:
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup), destination)
		return {"ok": false, "message": "ذخیرهٔ نهایی انجام نشد: %s" % error_string(rename_error)}
	return {"ok": true, "message": "بازی ذخیره شد."}


func load_state(catalog: GameCatalog, path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "missing": true, "message": "ذخیره‌ای برای ادامه وجود ندارد."}
	var primary: Dictionary = _read_candidate(catalog, path)
	if bool(primary.get("ok", false)) or bool(primary.get("unsupported_newer", false)):
		return primary
	var backup_path: String = ProjectSettings.globalize_path(path) + ".bak"
	if FileAccess.file_exists(backup_path):
		var backup_result: Dictionary = _read_candidate(catalog, backup_path)
		if bool(backup_result.get("ok", false)):
			backup_result["message"] = "ذخیرهٔ اصلی خراب بود؛ نسخهٔ پشتیبان بارگذاری شد."
			return backup_result
	return primary


func advance_offline(simulation: Simulation, elapsed_seconds: int) -> int:
	if simulation == null or simulation.catalog == null or elapsed_seconds <= 0:
		return 0
	var applied_seconds: int = mini(elapsed_seconds, simulation.catalog.balance.offline_cap_seconds)
	for _step: int in range(applied_seconds):
		simulation.tick(1.0)
	return applied_seconds


func _read_candidate(catalog: GameCatalog, path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "ذخیره خوانده نشد: %s" % error_string(FileAccess.get_open_error())}
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	if parse_error != Error.OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "message": "فایل ذخیره خراب است؛ بازی جدید آغاز شد."}
	var data: Dictionary = parser.data
	var version_value: Variant = data.get("save_version", null)
	if not _is_integer_number(version_value):
		return {"ok": false, "message": "نسخهٔ ذخیره مشخص نیست؛ فایل تغییر نکرد."}
	var version: int = int(version_value)
	if version > SAVE_VERSION:
		return {"ok": false, "unsupported_newer": true, "message": "این ذخیره با نسخهٔ جدیدتری از بازی ساخته شده و دست‌نخورده باقی ماند."}
	if version < 1 or version > SAVE_VERSION:
		return {"ok": false, "message": "مسیر مهاجرت این نسخهٔ ذخیره تعریف نشده است؛ فایل تغییر نکرد."}
	var candidate: GameState = _decode_state(catalog, data, version)
	if candidate == null:
		return {"ok": false, "message": "ساختار ذخیره نامعتبر است؛ فایل تغییر نکرد."}
	var migrated: bool = version < SAVE_VERSION
	var saved_money_before_migration: float = candidate.money
	var starting_money_adjusted: bool = version < 3 and candidate.money < catalog.balance.initial_money
	if starting_money_adjusted:
		candidate.money = maxf(candidate.money, catalog.balance.initial_money)
	if candidate.initial_storage_capacity < catalog.balance.initial_storage_capacity:
		candidate.initial_storage_capacity = catalog.balance.initial_storage_capacity
	return {
		"ok": true,
		"state": candidate,
		"migrated": migrated,
		"saved_money_before_migration": saved_money_before_migration,
		"starting_money_adjusted": starting_money_adjusted,
		"saved_unix_time": int(data.get("saved_unix_time", Time.get_unix_time_from_system())),
		"message": "ذخیره بارگذاری شد."
	}


func _decode_state(catalog: GameCatalog, data: Dictionary, version: int) -> GameState:
	var required_fields: Array[String] = ["money", "land_size", "initial_storage_capacity", "inventory", "market_rules", "next_building_id", "simulated_seconds", "cumulative_revenue", "buildings"]
	for field: String in required_fields:
		if not data.has(field):
			return null
	if not _is_number(data["money"]) or float(data["money"]) < 0.0:
		return null
	if not _is_integer_number(data["land_size"]) or int(data["land_size"]) < catalog.balance.initial_land_size or int(data["land_size"]) > catalog.balance.maximum_land_size:
		return null
	if not _is_number(data["initial_storage_capacity"]) or float(data["initial_storage_capacity"]) <= 0.0:
		return null
	if typeof(data["inventory"]) != TYPE_DICTIONARY or typeof(data["market_rules"]) != TYPE_DICTIONARY or typeof(data["buildings"]) != TYPE_ARRAY:
		return null
	var candidate: GameState = GameState.new()
	candidate.configure(catalog.resource_ids(), float(data["money"]), int(data["land_size"]), float(data["initial_storage_capacity"]), catalog.market_sell_defaults())
	for definition: BuildingDefinition in catalog.buildings.values():
		if definition.tier <= 1:
			candidate.unlocked_buildings[definition.id] = true
	if version >= 4:
		if typeof(data.get("unlocked_buildings", null)) != TYPE_DICTIONARY:
			return null
		var unlocked_rows: Dictionary = data["unlocked_buildings"]
		for building_id_value: Variant in unlocked_rows:
			var building_id: String = str(building_id_value)
			if not catalog.buildings.has(building_id) or typeof(unlocked_rows[building_id_value]) != TYPE_BOOL:
				return null
			if bool(unlocked_rows[building_id_value]):
				candidate.unlocked_buildings[building_id] = true
	var inventory_data: Dictionary = data["inventory"]
	for resource_id: String in catalog.resource_ids():
		if version < SAVE_VERSION and not inventory_data.has(resource_id):
			candidate.inventory[resource_id] = 0.0
			continue
		if not inventory_data.has(resource_id) or not _is_number(inventory_data[resource_id]) or float(inventory_data[resource_id]) < 0.0:
			return null
		candidate.inventory[resource_id] = float(inventory_data[resource_id])
	var rules_data: Dictionary = data["market_rules"]
	for resource_id: String in catalog.resource_ids():
		if version < SAVE_VERSION and not rules_data.has(resource_id):
			continue
		if not rules_data.has(resource_id) or typeof(rules_data[resource_id]) != TYPE_DICTIONARY:
			return null
		var rule: Dictionary = rules_data[resource_id]
		if typeof(rule.get("enabled", null)) != TYPE_BOOL or not _is_number(rule.get("minimum_stock", null)) or float(rule["minimum_stock"]) < 0.0:
			return null
		candidate.market_rules[resource_id] = {"enabled": bool(rule["enabled"]), "minimum_stock": float(rule["minimum_stock"])}
	var max_building_id: int = 0
	var seen_cells: Dictionary[Vector2i, bool] = {}
	for row_value: Variant in data["buildings"]:
		if typeof(row_value) != TYPE_DICTIONARY:
			return null
		var row: Dictionary = row_value
		if not _is_integer_number(row.get("id", null)) or not _is_integer_number(row.get("x", null)) or not _is_integer_number(row.get("y", null)) or not _is_integer_number(row.get("level", null)):
			return null
		var building_id: int = int(row["id"])
		var definition_id: String = str(row.get("definition_id", ""))
		if building_id <= 0 or not catalog.buildings.has(definition_id):
			return null
		var cell: Vector2i = Vector2i(int(row["x"]), int(row["y"]))
		if cell.x < 0 or cell.y < 0 or cell.x >= candidate.land_size or cell.y >= candidate.land_size or seen_cells.has(cell):
			return null
		var definition: BuildingDefinition = catalog.buildings[definition_id]
		if int(row["level"]) < 1 or int(row["level"]) > definition.max_level:
			return null
		var stored_energy: Variant = row.get("energy_stored", 0.0 if version < 2 else null)
		if not _is_number(stored_energy) or float(stored_energy) < 0.0:
			return null
		if definition.kind == "battery":
			if float(stored_energy) > definition.battery_capacity * float(int(row["level"])) + catalog.balance.production_tolerance:
				return null
		elif float(stored_energy) > catalog.balance.production_tolerance:
			return null
		seen_cells[cell] = true
		max_building_id = maxi(max_building_id, building_id)
		var building: BuildingInstance = BuildingInstance.new()
		building.id = building_id
		building.definition_id = definition_id
		building.cell = cell
		building.level = int(row["level"])
		building.energy_stored = float(stored_energy)
		candidate.buildings.append(building)
	if not _is_integer_number(data["next_building_id"]) or int(data["next_building_id"]) <= max_building_id:
		return null
	if not _is_number(data["simulated_seconds"]) or float(data["simulated_seconds"]) < 0.0 or not _is_number(data["cumulative_revenue"]) or float(data["cumulative_revenue"]) < 0.0:
		return null
	candidate.next_building_id = int(data["next_building_id"])
	candidate.simulated_seconds = float(data["simulated_seconds"])
	candidate.cumulative_revenue = float(data["cumulative_revenue"])
	var cumulative_production: Variant = data.get("cumulative_production", 0.0)
	var prestige_points: Variant = data.get("prestige_points", 0)
	var prestige_count: Variant = data.get("prestige_count", 0)
	var sound_enabled: Variant = data.get("sound_enabled", true)
	if not _is_number(cumulative_production) or float(cumulative_production) < 0.0 or not _is_integer_number(prestige_points) or int(prestige_points) < 0 or not _is_integer_number(prestige_count) or int(prestige_count) < 0 or typeof(sound_enabled) != TYPE_BOOL:
		return null
	candidate.cumulative_production = float(cumulative_production)
	if version < 4:
		for definition: BuildingDefinition in catalog.buildings.values():
			if definition.tier == 2 and (candidate.cumulative_revenue >= catalog.balance.tier_two_revenue or candidate.cumulative_production >= catalog.balance.tier_two_production):
				candidate.unlocked_buildings[definition.id] = true
			elif definition.tier == 3 and (candidate.cumulative_revenue >= catalog.balance.tier_three_revenue or candidate.cumulative_production >= catalog.balance.tier_three_production):
				candidate.unlocked_buildings[definition.id] = true
	candidate.prestige_points = int(prestige_points)
	candidate.prestige_count = int(prestige_count)
	candidate.sound_enabled = bool(sound_enabled)
	var capacity: float = candidate.initial_storage_capacity
	for building: BuildingInstance in candidate.buildings:
		var definition: BuildingDefinition = catalog.buildings[building.definition_id]
		if definition.kind == "storage":
			capacity += definition.storage_capacity * float(building.level)
	var inventory_total: float = 0.0
	for amount: float in candidate.inventory.values():
		inventory_total += amount
	if inventory_total > capacity + catalog.balance.production_tolerance:
		return null
	return candidate


func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _is_integer_number(value: Variant) -> bool:
	return _is_number(value) and float(value) == float(int(value))
