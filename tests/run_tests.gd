extends Node

const TestWorldGrid = preload("res://src/presentation/world_grid.gd")

var _catalog: GameCatalog = GameCatalog.new()
var _failures: int = 0
var _assertions: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_valid_data()
	_test_new_art_and_sound_assets_load()
	_test_duplicate_id_validation()
	_test_invalid_reference_validation()
	_test_missing_source_building_validation()
	_test_wrong_type_validation()
	_test_negative_quantity_validation()
	_test_malformed_json_validation()
	_test_build_validation_and_atomic_failure()
	_test_demolition_refund()
	_test_grid_coordinate_mapping()
	_test_fixed_step_and_repeatability()
	_test_storage_cap_and_no_negative_inventory()
	_test_new_output_is_not_used_in_same_tick()
	_test_market_minimum_stock_and_toggle()
	_test_multiple_market_capacity()
	_test_instant_market_sale()
	_test_secondary_building_production_and_warning()
	_test_power_shortage_scales_consumers_uniformly()
	_test_fuel_depletion_stops_coal_generation()
	_test_battery_charge_discharge()
	_test_idle_consumers_do_not_request_power()
	_test_battery_energy_save_round_trip()
	_test_phase_three_save_migrates()
	_test_manual_shop_sale_and_clear_stock_feedback()
	_test_tiers_expansion_and_cardinal_adjacency()
	_test_offline_progress_and_cap()
	_test_prestige_reset_and_bonus()
	_test_raw_vs_processed_value()
	_test_upgrade_limits_and_storage()
	_test_five_minute_play_and_save_continue()
	_test_save_round_trip()
	_test_car_production_chain()
	_test_city_buildings_upgrade_to_ten()
	if _failures == 0:
		print("PASS: %d assertions" % _assertions)
		get_tree().quit(0)
	else:
		printerr("FAIL: %d of %d assertions failed" % [_failures, _assertions])
		get_tree().quit(1)


func _test_valid_data() -> void:
	var loaded: bool = _catalog.load_from_files("res://data/resources.json", "res://data/recipes.json", "res://data/buildings.json", "res://data/balance.json")
	if not loaded:
		for message: String in _catalog.errors:
			printerr("CATALOG: %s" % message)
	_expect(loaded, "valid JSON definitions load")
	_expect(_catalog.resources.size() == 24 and _catalog.recipes.size() == 24 and _catalog.buildings.size() == 36, "catalog loads all raw materials, recipes, factories, service and city buildings")
	_expect(_catalog.balance.tick_seconds == 0.1 and _catalog.balance.initial_land_size == 8 and _catalog.balance.initial_money == 500.0, "balance contract loads with increased starting cash")


func _test_new_art_and_sound_assets_load() -> void:
	for definition_id: String in ["corn_farm", "cotton_farm", "iron_mine", "copper_mine", "gas_well", "sand_quarry", "gas_plant", "steel_mill", "cement_works", "glassworks", "cable_factory", "electronics_factory", "food_factory", "textile_mill", "park", "rubber_farm", "tire_factory", "paint_works", "engine_factory", "body_factory", "car_factory", "house", "pine", "oak"]:
		var texture: Texture2D = load("res://assets/sprites/%s.svg" % definition_id) as Texture2D
		_expect(texture != null, "phase 5–9 sprite loads: %s" % definition_id)
	for city_id: String in ["house", "pine", "oak"]:
		for city_level: int in range(1, 11):
			var level_texture: Texture2D = load("res://assets/sprites/%s_%d.svg" % [city_id, city_level]) as Texture2D
			_expect(level_texture != null, "city sprite loads: %s level %d" % [city_id, city_level])
	var main_script: GDScript = load("res://src/presentation/main.gd") as GDScript
	var main_instance: Control = main_script.new() as Control
	var sound: AudioStreamWAV = main_instance.call("_make_ui_sound") as AudioStreamWAV
	_expect(sound != null and sound.data.size() > 0, "interface sound is generated without an external audio asset")
	main_instance.free()


func _test_duplicate_id_validation() -> void:
	var broken: GameCatalog = GameCatalog.new()
	var loaded: bool = broken.load_from_files("res://tests/fixtures/resources_duplicate.json", "res://data/recipes.json", "res://data/buildings.json", "res://data/balance.json")
	_expect(not loaded, "duplicate resource data is rejected")
	_expect(_errors_contain(broken, "شناسهٔ تکراری"), "duplicate error identifies the invalid ID")


func _test_invalid_reference_validation() -> void:
	var broken: GameCatalog = GameCatalog.new()
	var loaded: bool = broken.load_from_files("res://data/resources.json", "res://tests/fixtures/recipes_bad_reference.json", "res://data/buildings.json", "res://data/balance.json")
	_expect(not loaded, "missing resource reference is rejected")
	_expect(_errors_contain(broken, "ghost_resource"), "invalid reference is named in the validation error")


func _test_missing_source_building_validation() -> void:
	var broken: GameCatalog = GameCatalog.new()
	var loaded: bool = broken.load_from_files("res://data/resources.json", "res://data/recipes.json", "res://tests/fixtures/buildings_no_wheat_source.json", "res://data/balance.json")
	_expect(not loaded, "recipe input without a producer building is rejected")
	_expect(_errors_contain(broken, "wheat"), "missing source error names the unsupplied resource")


func _test_wrong_type_validation() -> void:
	var broken: GameCatalog = GameCatalog.new()
	var loaded: bool = broken.load_from_files("res://tests/fixtures/resources_bad_type.json", "res://data/recipes.json", "res://data/buildings.json", "res://data/balance.json")
	_expect(not loaded, "wrong JSON field types are rejected")
	_expect(_errors_contain(broken, "unit_price"), "wrong-type error identifies the field")


func _test_negative_quantity_validation() -> void:
	var broken: GameCatalog = GameCatalog.new()
	var loaded: bool = broken.load_from_files("res://data/resources.json", "res://tests/fixtures/recipes_negative_quantity.json", "res://data/buildings.json", "res://data/balance.json")
	_expect(not loaded, "negative recipe quantity is rejected")
	_expect(_errors_contain(broken, "outputs[flour]"), "negative quantity error identifies the resource")


func _test_malformed_json_validation() -> void:
	var broken: GameCatalog = GameCatalog.new()
	var loaded: bool = broken.load_from_files("res://tests/fixtures/malformed.json", "res://data/recipes.json", "res://data/buildings.json", "res://data/balance.json")
	_expect(not loaded, "malformed JSON is rejected")
	_expect(_errors_contain(broken, "JSON نامعتبر"), "malformed JSON reports its source")


func _test_build_validation_and_atomic_failure() -> void:
	var simulation: Simulation = _new_simulation()
	var built: CommandResult = _command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
	_expect(built.succeeded and built.subject_id == 1, "valid construction assigns a stable ID")
	var funds_after_build: float = simulation.state.money
	var occupied: CommandResult = _command(simulation, GameCommand.build("market", Vector2i(0, 0)))
	_expect(not occupied.succeeded and simulation.state.money == funds_after_build and simulation.state.buildings.size() == 1, "occupied-cell failure has no partial effects")
	var outside: CommandResult = _command(simulation, GameCommand.build("market", Vector2i(8, 0)))
	_expect(not outside.succeeded and simulation.state.money == funds_after_build, "outside-land failure has no partial effects")
	var unknown: CommandResult = _command(simulation, GameCommand.build("unknown", Vector2i(1, 0)))
	_expect(not unknown.succeeded and simulation.state.buildings.size() == 1, "unknown building is rejected")
	var low_funds_simulation: Simulation = _new_simulation()
	for index: int in range(13):
		var cell: Vector2i = Vector2i(index % 8, int(index / 8))
		_expect(_command(low_funds_simulation, GameCommand.build("tree_lot", cell)).succeeded, "test setup builds affordable tree lot %d" % index)
	var money_before_failure: float = low_funds_simulation.state.money
	var unaffordable: CommandResult = _command(low_funds_simulation, GameCommand.build("farm", Vector2i(4, 0)))
	_expect(not unaffordable.succeeded and low_funds_simulation.state.money == money_before_failure, "insufficient-funds failure is atomic")


func _test_demolition_refund() -> void:
	var simulation: Simulation = _new_simulation()
	var built: CommandResult = _command(simulation, GameCommand.build("farm", Vector2i(2, 2)))
	var money_before: float = simulation.state.money
	var deleted: CommandResult = _command(simulation, GameCommand.demolish(built.subject_id))
	_expect(deleted.succeeded and simulation.state.buildings.is_empty(), "confirmed demolition removes the selected building")
	_expect(is_equal_approx(simulation.state.money, money_before + 21.0), "demolition refunds the configured half construction cost")
	var invalid: CommandResult = _command(simulation, GameCommand.demolish(999))
	_expect(not invalid.succeeded and is_equal_approx(simulation.state.money, money_before + 21.0), "missing building demolition is rejected without changing money")
	var warehouse_simulation: Simulation = _new_simulation()
	var first_warehouse: CommandResult = _command(warehouse_simulation, GameCommand.build("warehouse", Vector2i(0, 0)))
	_command(warehouse_simulation, GameCommand.build("warehouse", Vector2i(1, 0)))
	warehouse_simulation.state.inventory["wheat"] = 4000.0
	var warehouse_money: float = warehouse_simulation.state.money
	var blocked_storage_demolition: CommandResult = _command(warehouse_simulation, GameCommand.demolish(first_warehouse.subject_id))
	_expect(not blocked_storage_demolition.succeeded and warehouse_simulation.state.money == warehouse_money and warehouse_simulation.state.buildings.size() == 2, "warehouse cannot be demolished below current shared inventory")


func _test_grid_coordinate_mapping() -> void:
	var grid: Control = TestWorldGrid.new() as Control
	grid.size = Vector2(640.0, 640.0)
	var empty_buildings: Array[Dictionary] = []
	grid.call("set_game_view", 8, empty_buildings, "", 0, 180.0, 0.0)
	var first_cell: Variant = grid.call("_cell_at", Vector2(84.8, 84.8))
	var last_cell: Variant = grid.call("_cell_at", Vector2(588.0, 588.0))
	var outside_cell: Variant = grid.call("_cell_at", Vector2(40.0, 40.0))
	_expect(first_cell is Vector2i and first_cell == Vector2i(0, 0), "grid maps a click to the expected first cell")
	_expect(last_cell is Vector2i and last_cell == Vector2i(7, 7), "grid maps a click to the expected last cell")
	_expect(outside_cell is Vector2i and outside_cell == Vector2i(-1, -1), "grid rejects coordinates outside the plot")
	var maximum_board: Array[Dictionary] = []
	for y: int in range(24):
		for x: int in range(24):
			maximum_board.append({"id": y * 24 + x + 1, "cell": Vector2i(x, y), "neighbor_bonus": 0.0})
	grid.call("set_game_view", 24, maximum_board, "", 0, 500.0, 0.0)
	var max_tile_size: float = float(grid.call("_tile_size"))
	_expect(maximum_board.size() == 576 and max_tile_size * 24.0 <= grid.size.x, "24×24 grid geometry fits all 576 cells in the viewport")
	grid.free()


func _test_fixed_step_and_repeatability() -> void:
	var first: Simulation = _new_simulation()
	var second: Simulation = _new_simulation()
	for simulation: Simulation in [first, second]:
		_command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
		_command(simulation, GameCommand.build("market", Vector2i(1, 0)))
		for _step: int in range(100):
			simulation.tick(0.1)
	_expect(is_equal_approx(first.state.money, second.state.money), "same data and commands produce the same money")
	_expect(is_equal_approx(first.state.inventory["wheat"], second.state.inventory["wheat"]), "same data and commands produce the same inventory")
	_expect(first.tick_count == 100 and is_equal_approx(first.state.simulated_seconds, 10.0), "simulation advances only by explicit fixed steps")


func _test_storage_cap_and_no_negative_inventory() -> void:
	var simulation: Simulation = _new_simulation()
	_command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
	simulation.state.inventory["wheat"] = 1999.0
	for _step: int in range(100):
		simulation.tick(0.1)
	_expect(is_equal_approx(simulation.state.inventory["wheat"], 2000.0), "full storage stops further production")
	_expect(simulation.state.storage_used() <= simulation.get_storage_capacity() + 0.000001, "storage capacity is never exceeded")
	for amount: float in simulation.state.inventory.values():
		_expect(amount >= 0.0, "inventory never becomes negative")


func _test_new_output_is_not_used_in_same_tick() -> void:
	var simulation: Simulation = _new_simulation()
	_command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
	_command(simulation, GameCommand.build("flour_mill", Vector2i(1, 0)))
	_command(simulation, GameCommand.build("solar_plant", Vector2i(2, 0)))
	simulation.tick(0.1)
	_expect(is_equal_approx(simulation.state.inventory["wheat"], 0.07), "mill cannot use farm output from the same producer pass")
	_expect(is_equal_approx(simulation.state.inventory["flour"], 0.0), "no flour is created without start-of-pass wheat")
	simulation.tick(0.1)
	_expect(simulation.state.inventory["flour"] > 0.0, "mill processes stored wheat on the next tick")
	_expect(simulation.state.inventory["wheat"] >= 0.0, "recipe inputs remain nonnegative")


func _test_market_minimum_stock_and_toggle() -> void:
	var reserved_simulation: Simulation = _new_simulation()
	_command(reserved_simulation, GameCommand.build("farm", Vector2i(0, 0)))
	_command(reserved_simulation, GameCommand.build("market", Vector2i(1, 0)))
	_command(reserved_simulation, GameCommand.set_market_rule("wheat", true, 3.0))
	for _step: int in range(100):
		reserved_simulation.tick(0.1)
	_expect(float(reserved_simulation.state.inventory["wheat"]) >= 3.0 - 0.000001, "market never sells below the configured minimum stock")
	var disabled_simulation: Simulation = _new_simulation()
	_command(disabled_simulation, GameCommand.build("farm", Vector2i(0, 0)))
	_command(disabled_simulation, GameCommand.build("market", Vector2i(1, 0)))
	_command(disabled_simulation, GameCommand.set_market_rule("wheat", false, 0.0))
	for _step: int in range(100):
		disabled_simulation.tick(0.1)
	_expect(is_equal_approx(disabled_simulation.state.inventory["wheat"], 7.0), "disabled market rule retains the full production")
	_expect(is_equal_approx(disabled_simulation.state.cumulative_revenue, 0.0), "disabled market rule creates no revenue")


func _test_multiple_market_capacity() -> void:
	var one_market: Simulation = _new_simulation()
	var two_markets: Simulation = _new_simulation()
	for simulation: Simulation in [one_market, two_markets]:
		_command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
		_command(simulation, GameCommand.build("market", Vector2i(1, 0)))
	_command(two_markets, GameCommand.build("market", Vector2i(2, 0)))
	for _step: int in range(100):
		one_market.tick(0.1)
		two_markets.tick(0.1)
	_expect(is_equal_approx(one_market.state.cumulative_revenue, 16.8), "one market instantly sells everything above minimum stock")
	_expect(is_equal_approx(two_markets.state.cumulative_revenue, 16.8), "extra markets add no per-second cap; nothing is sold twice")
	_expect(is_equal_approx(float(one_market.state.inventory["wheat"]), 0.0), "instant sale leaves no leftover stock above minimum")
	_expect(two_markets.state.inventory["wheat"] >= -0.000001, "combined instant sale keeps inventory nonnegative")


func _test_instant_market_sale() -> void:
	var simulation: Simulation = _new_simulation()
	_command(simulation, GameCommand.build("market", Vector2i(0, 0)))
	simulation.state.inventory["wheat"] = 100.0
	_command(simulation, GameCommand.set_market_rule("wheat", true, 10.0))
	simulation.tick(0.1)
	_expect(is_equal_approx(float(simulation.state.inventory["wheat"]), 10.0), "enabled sale keeps the configured stock and sells the rest in the same tick")
	_expect(is_equal_approx(simulation.state.cumulative_revenue, 90.0 * 2.4), "everything above minimum converts to revenue immediately")
	var no_market: Simulation = _new_simulation()
	no_market.state.inventory["wheat"] = 100.0
	_command(no_market, GameCommand.set_market_rule("wheat", true, 0.0))
	no_market.tick(0.1)
	_expect(is_equal_approx(float(no_market.state.inventory["wheat"]), 100.0), "no market building means no automatic sale")
	_expect(is_equal_approx(no_market.state.cumulative_revenue, 0.0), "no market building means no automatic revenue")


func _test_secondary_building_production_and_warning() -> void:
	var simulation: Simulation = _new_simulation()
	simulation.state.money = 1000.0
	_command(simulation, GameCommand.build("tree_lot", Vector2i(0, 0)))
	_command(simulation, GameCommand.build("stone_quarry", Vector2i(1, 0)))
	_command(simulation, GameCommand.build("flour_mill", Vector2i(2, 0)))
	_command(simulation, GameCommand.build("wind_turbine", Vector2i(3, 0)))
	for _step: int in range(100):
		simulation.tick(0.1)
	_expect(is_equal_approx(simulation.state.inventory["wood"], 3.5), "tree lot produces its configured wood recipe")
	_expect(is_equal_approx(simulation.state.inventory["stone"], 3.0), "quarry produces its configured stone recipe")
	var mill_status: String = ""
	for row: Dictionary in simulation.get_snapshot()["buildings"]:
		if str(row["definition_id"]) == "flour_mill":
			mill_status = str(row["status"])
	_expect(mill_status == "no_input", "mill reports a clear missing-input status")


func _test_power_shortage_scales_consumers_uniformly() -> void:
	var simulation: Simulation = _new_simulation()
	simulation.state.money = 1000.0
	var quarry_result: CommandResult = _command(simulation, GameCommand.build("stone_quarry", Vector2i(0, 0)))
	var mill_result: CommandResult = _command(simulation, GameCommand.build("flour_mill", Vector2i(1, 0)))
	_command(simulation, GameCommand.build("solar_plant", Vector2i(2, 0)))
	simulation.state.inventory["wheat"] = 10.0
	simulation.tick(0.1)
	var ratio: float = 1.8 / 3.8
	var quarry: BuildingInstance = simulation.find_building(quarry_result.subject_id)
	var mill: BuildingInstance = simulation.find_building(mill_result.subject_id)
	_expect(is_equal_approx(simulation.power_demand_per_second, 3.8), "only active powered producers contribute to the shared demand")
	_expect(is_equal_approx(simulation.power_ratio, ratio) and simulation.power_shortage, "solar shortage produces a shared proportional power ratio")
	_expect(is_equal_approx(float(quarry.last_outputs["stone"]), 0.03 * ratio), "quarry production follows the shared low-power ratio")
	_expect(is_equal_approx(float(mill.last_outputs["flour"]), 0.0495 * ratio), "mill production follows the same shared low-power ratio")
	_expect(quarry.status == "power_limited" and mill.status == "power_limited", "both active consumers report proportional power limitation")


func _test_fuel_depletion_stops_coal_generation() -> void:
	var simulation: Simulation = _new_simulation()
	simulation.state.money = 1000.0
	simulation.state.inventory["coal"] = 0.0264
	var power_result: CommandResult = _command(simulation, GameCommand.build("coal_plant", Vector2i(0, 0)))
	_command(simulation, GameCommand.build("stone_quarry", Vector2i(1, 0)))
	simulation.tick(0.1)
	var power_plant: BuildingInstance = simulation.find_building(power_result.subject_id)
	_expect(is_equal_approx(float(simulation.state.inventory["coal"]), 0.0), "coal plant consumes only the fuel required for its delivered energy")
	_expect(is_equal_approx(simulation.power_ratio, 1.0), "available coal fully powers demand until the final fuel amount is used")
	simulation.tick(0.1)
	_expect(power_plant.status == "out_of_fuel" and simulation.power_shortage, "fuel depletion stops coal generation and exposes a power shortage")
	_expect(is_equal_approx(simulation.power_ratio, 0.0), "empty coal stock supplies no electricity")


func _test_battery_charge_discharge() -> void:
	var simulation: Simulation = _new_simulation()
	simulation.state.money = 1000.0
	_command(simulation, GameCommand.build("solar_plant", Vector2i(0, 0)))
	var battery_result: CommandResult = _command(simulation, GameCommand.build("battery", Vector2i(1, 0)))
	for _step: int in range(10):
		simulation.tick(0.1)
	var battery: BuildingInstance = simulation.find_building(battery_result.subject_id)
	_expect(is_equal_approx(battery.energy_stored, 1.2), "battery stores surplus renewable energy up to its charge rate")
	_expect(battery.status == "charging", "battery reports the charging state")
	simulation.state.inventory["wheat"] = 10.0
	_command(simulation, GameCommand.build("stone_quarry", Vector2i(2, 0)))
	_command(simulation, GameCommand.build("flour_mill", Vector2i(3, 0)))
	simulation.tick(0.1)
	_expect(is_equal_approx(battery.energy_stored, 1.08), "battery releases energy at its configured discharge rate during a deficit")
	_expect(battery.status == "discharging" and simulation.power_shortage, "battery discharge is visible while consumers still share a shortage")
	for _step: int in range(9):
		simulation.tick(0.1)
	_expect(is_equal_approx(battery.energy_stored, 0.0), "battery energy cannot fall below zero")


func _test_idle_consumers_do_not_request_power() -> void:
	var no_input: Simulation = _new_simulation()
	_command(no_input, GameCommand.build("flour_mill", Vector2i(0, 0)))
	no_input.tick(0.1)
	_expect(is_equal_approx(no_input.power_demand_per_second, 0.0) and not no_input.power_shortage, "consumer without recipe inputs does not inflate electric demand")
	var full_storage: Simulation = _new_simulation()
	full_storage.state.inventory["wheat"] = 2000.0
	var quarry_result: CommandResult = _command(full_storage, GameCommand.build("stone_quarry", Vector2i(0, 0)))
	full_storage.tick(0.1)
	var quarry: BuildingInstance = full_storage.find_building(quarry_result.subject_id)
	_expect(is_equal_approx(full_storage.power_demand_per_second, 0.0), "consumer blocked by full storage does not request electricity")
	_expect(quarry.status == "storage_full", "storage shortage is reported instead of a false power warning")


func _test_battery_energy_save_round_trip() -> void:
	var simulation: Simulation = _new_simulation()
	_command(simulation, GameCommand.build("solar_plant", Vector2i(0, 0)))
	var battery_result: CommandResult = _command(simulation, GameCommand.build("battery", Vector2i(1, 0)))
	for _step: int in range(5):
		simulation.tick(0.1)
	var energy_before: float = simulation.find_building(battery_result.subject_id).energy_stored
	var service: SaveService = SaveService.new()
	var save_path: String = "res://tests/.tmp_battery_energy.json"
	var save_result: Dictionary = service.save_state(simulation.state, save_path)
	var load_result: Dictionary = service.load_state(_catalog, save_path)
	_expect(bool(save_result["ok"]) and bool(load_result.get("ok", false)), "battery state is saved and loaded")
	if bool(load_result.get("ok", false)):
		var restored: Simulation = _new_simulation()
		_expect(restored.restore_state(load_result["state"]), "saved battery state passes simulation validation")
		var restored_energy: float = restored.find_building(battery_result.subject_id).energy_stored
		_expect(is_equal_approx(restored_energy, energy_before), "save round trip preserves the battery energy level")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".bak"))


func _test_phase_three_save_migrates() -> void:
	var legacy_data: Dictionary = {
		"save_version": 1,
		"money": 120.0,
		"land_size": 8,
		"initial_storage_capacity": 40.0,
		"inventory": {"wheat": 1.5, "wood": 0.0, "stone": 0.0, "flour": 0.0},
		"market_rules": {
			"wheat": {"enabled": true, "minimum_stock": 0.0},
			"wood": {"enabled": true, "minimum_stock": 0.0},
			"stone": {"enabled": true, "minimum_stock": 0.0},
			"flour": {"enabled": true, "minimum_stock": 0.0}
		},
		"next_building_id": 1,
		"simulated_seconds": 10.0,
		"cumulative_revenue": 0.0,
		"buildings": []
	}
	var save_path: String = "res://tests/.tmp_phase_three_migration.json"
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_data))
	file.close()
	var loaded: Dictionary = SaveService.new().load_state(_catalog, save_path)
	_expect(bool(loaded.get("ok", false)), "phase 3 version-1 save migrates with its old data intact")
	if bool(loaded.get("ok", false)):
		var migrated: GameState = loaded["state"] as GameState
		_expect(is_equal_approx(float(migrated.inventory["coal"]), 0.0), "new stock starts empty when migrating an older save")
		_expect(not bool(migrated.market_rules["coal"]["enabled"]), "coal sale uses its safe default after migration")
		_expect(is_equal_approx(migrated.money, 500.0), "legacy save receives the new starting-cash floor once")
		_expect(is_equal_approx(migrated.initial_storage_capacity, 2000.0), "legacy save receives the new starting-storage floor")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".bak"))
	var version_two_data: Dictionary = legacy_data.duplicate(true)
	version_two_data["save_version"] = 2
	var version_two_path: String = "res://tests/.tmp_phase_four_migration.json"
	var version_two_file: FileAccess = FileAccess.open(version_two_path, FileAccess.WRITE)
	version_two_file.store_string(JSON.stringify(version_two_data))
	version_two_file.close()
	var version_two_result: Dictionary = SaveService.new().load_state(_catalog, version_two_path)
	_expect(bool(version_two_result.get("ok", false)) and bool(version_two_result.get("migrated", false)), "phase 4 version-2 save migrates into the current format")
	if bool(version_two_result.get("ok", false)):
		var version_two_state: GameState = version_two_result["state"] as GameState
		_expect(is_equal_approx(version_two_state.money, 500.0) and is_equal_approx(float(version_two_state.inventory["electronics"]), 0.0), "version-2 migration adds new stocks safely and applies starting cash")
		_expect(bool(SaveService.new().save_state(version_two_state, version_two_path).get("ok", false)), "migrated version-2 save commits in the new format")
		var migrated_again: Dictionary = SaveService.new().load_state(_catalog, version_two_path)
		_expect(bool(migrated_again.get("ok", false)) and not bool(migrated_again.get("migrated", true)) and is_equal_approx((migrated_again["state"] as GameState).money, 500.0), "starting-cash migration is not granted a second time")
	var wealthy_legacy_data: Dictionary = version_two_data.duplicate(true)
	wealthy_legacy_data["money"] = 850.0
	var wealthy_legacy_path: String = "res://tests/.tmp_wealthy_legacy.json"
	var wealthy_legacy_file: FileAccess = FileAccess.open(wealthy_legacy_path, FileAccess.WRITE)
	wealthy_legacy_file.store_string(JSON.stringify(wealthy_legacy_data))
	wealthy_legacy_file.close()
	var wealthy_legacy_result: Dictionary = SaveService.new().load_state(_catalog, wealthy_legacy_path)
	_expect(bool(wealthy_legacy_result.get("ok", false)) and is_equal_approx((wealthy_legacy_result["state"] as GameState).money, 850.0), "legacy migration preserves balances above the new starting floor")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(wealthy_legacy_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(version_two_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(version_two_path + ".bak"))


func _test_manual_shop_sale_and_clear_stock_feedback() -> void:
	var simulation: Simulation = _new_simulation()
	_expect(is_equal_approx(simulation.state.money, 500.0), "new city starts with $500")
	var no_shop: CommandResult = _command(simulation, GameCommand.sell_resource("wheat"))
	_expect(not no_shop.succeeded and no_shop.code == "shop_required", "manual sale reports that a shop is required")
	var shop_result: CommandResult = _command(simulation, GameCommand.build("shop", Vector2i(0, 0)))
	var farm_result: CommandResult = _command(simulation, GameCommand.build("farm", Vector2i(1, 0)))
	_expect(shop_result.succeeded and farm_result.succeeded, "starting cash can fund a shop and a producer")
	var no_stock: CommandResult = _command(simulation, GameCommand.sell_resource("wheat"))
	_expect(not no_stock.succeeded and no_stock.code == "no_stock", "empty-stock sale reports why it cannot proceed")
	simulation.state.inventory["wheat"] = 4.5
	var cash_before_sale: float = simulation.state.money
	var sale: CommandResult = _command(simulation, GameCommand.sell_resource("wheat"))
	_expect(sale.succeeded and sale.code == "manual_sale", "shop sells stock without a market building")
	_expect(is_equal_approx(float(simulation.state.inventory["wheat"]), 0.0) and is_equal_approx(simulation.state.money, cash_before_sale + 10.8), "manual sale clears the chosen stock and credits its unit-price value")


func _test_tiers_expansion_and_cardinal_adjacency() -> void:
	var simulation: Simulation = _new_simulation()
	var locked: CommandResult = _command(simulation, GameCommand.build("corn_farm", Vector2i(0, 0)))
	_expect(not locked.succeeded and locked.code == "building_locked", "tier 2 buildings stay locked until a goal is met")
	var expansion: CommandResult = _command(simulation, GameCommand.expand_land())
	_expect(expansion.succeeded and simulation.state.land_size == 12 and is_equal_approx(simulation.state.money, 320.0), "first land expansion charges its configured cost")
	simulation.state.money = 2000.0
	simulation.state.cumulative_production = 150.0
	_expect(_command(simulation, GameCommand.unlock_building("park")).succeeded, "park route unlocks with funds")
	var farm_result: CommandResult = _command(simulation, GameCommand.build("farm", Vector2i(4, 4)))
	var diagonal_park: CommandResult = _command(simulation, GameCommand.build("park", Vector2i(3, 3)))
	_expect(farm_result.succeeded and diagonal_park.succeeded, "unlocked park builds next to the farm")
	var farm: BuildingInstance = simulation.find_building(farm_result.subject_id)
	_expect(is_equal_approx(simulation.get_neighbor_bonus(farm), 0.0), "diagonal parks do not grant adjacency bonuses")
	for cell: Vector2i in [Vector2i(4, 3), Vector2i(4, 5), Vector2i(3, 4), Vector2i(5, 4)]:
		_expect(_command(simulation, GameCommand.build("park", cell)).succeeded, "cardinal park placement succeeds")
	_expect(is_equal_approx(simulation.get_neighbor_bonus(farm), 0.4), "cardinal adjacency bonus is capped at 40 percent")
	_expect(simulation.get_neighbor_details(farm).size() == 4, "inspector data identifies each affected cardinal neighbor")
	var adjacent_park: BuildingInstance = simulation.find_building_at(Vector2i(4, 3))
	_expect(simulation.get_affected_neighbors(adjacent_park).size() == 1, "park inspector lists the cardinal building it boosts")
	var removed_park_cell: Vector2i = adjacent_park.cell
	_expect(_command(simulation, GameCommand.demolish(adjacent_park.id)).succeeded and is_equal_approx(simulation.get_neighbor_bonus(farm), 0.36), "demolition immediately refreshes cardinal adjacency bonuses")
	_expect(_command(simulation, GameCommand.build("park", removed_park_cell)).succeeded and is_equal_approx(simulation.get_neighbor_bonus(farm), 0.4), "rebuilding a park restores the capped bonus")
	simulation.state.cumulative_revenue = 450.0
	var second_expansion: CommandResult = _command(simulation, GameCommand.expand_land())
	_expect(second_expansion.succeeded and simulation.state.land_size == 16 and simulation.find_building(farm.id) != null, "later expansion preserves the existing board and buildings")
	simulation.state.cumulative_production = 900.0
	_expect(simulation.is_tier_unlocked(3), "tier 3 unlocks from cumulative production")
	_expect(_command(simulation, GameCommand.unlock_building("electronics_factory")).succeeded, "tier 3 factory route unlocks with funds")
	var electronics: CommandResult = _command(simulation, GameCommand.build("electronics_factory", Vector2i(10, 10)))
	_expect(electronics.succeeded, "tier 3 factory becomes buildable after unlocking")
	simulation.state.money = 10000.0
	simulation.state.cumulative_revenue = 1200.0
	_expect(_command(simulation, GameCommand.expand_land()).succeeded and simulation.state.land_size == 20, "third expansion reaches a 20×20 plot")
	simulation.state.cumulative_revenue = 3000.0
	_expect(_command(simulation, GameCommand.expand_land()).succeeded and simulation.state.land_size == 24 and simulation.find_building(electronics.subject_id) != null, "final expansion reaches 24×24 and preserves all old cells")


func _test_offline_progress_and_cap() -> void:
	var simulation: Simulation = _new_simulation()
	_command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
	_command(simulation, GameCommand.build("market", Vector2i(1, 0)))
	var service: SaveService = SaveService.new()
	var negative_result: int = service.advance_offline(simulation, -30)
	_expect(negative_result == 0 and is_equal_approx(simulation.state.simulated_seconds, 0.0), "negative elapsed time grants nothing")
	var money_before_offline: float = simulation.state.money
	var rollback_copy: GameState = simulation.state.copy_state()
	var applied: int = service.advance_offline(simulation, 30)
	_expect(applied == 30 and is_equal_approx(simulation.state.simulated_seconds, 30.0), "offline simulation advances in bounded one-second steps")
	_expect(simulation.state.money > money_before_offline and simulation.state.storage_used() <= simulation.get_storage_capacity() + 0.000001, "offline production obeys market sales and shared storage")
	_expect(is_equal_approx(rollback_copy.simulated_seconds, 0.0) and is_equal_approx(float(rollback_copy.inventory["wheat"]), 0.0) and is_equal_approx(rollback_copy.money, money_before_offline), "offline rollback snapshot remains unchanged when catch-up runs")
	var reference: Simulation = _new_simulation()
	_command(reference, GameCommand.build("farm", Vector2i(0, 0)))
	_command(reference, GameCommand.build("market", Vector2i(1, 0)))
	for _step: int in range(300):
		reference.tick(0.1)
	_expect(is_equal_approx(reference.state.money, simulation.state.money), "one-second offline batches match fixed-step sales for a steady farm route")
	_expect(is_equal_approx(reference.state.inventory["wheat"], simulation.state.inventory["wheat"]), "one-second offline batches preserve the steady route's stock")
	var save_path: String = "res://tests/.tmp_offline_once.json"
	_expect(bool(service.save_state(simulation.state, save_path).get("ok", false)), "offline result is persisted before the next load")
	var loaded: Dictionary = service.load_state(_catalog, save_path)
	var resumed: Simulation = _new_simulation()
	if bool(loaded.get("ok", false)):
		resumed.restore_state(loaded["state"])
		var elapsed_after_save: int = maxi(0, int(Time.get_unix_time_from_system()) - int(loaded["saved_unix_time"]))
		service.advance_offline(resumed, elapsed_after_save)
		_expect(resumed.state.simulated_seconds - simulation.state.simulated_seconds <= 1.0 + 0.000001, "a saved offline claim is not replayed on the next load")
	else:
		_expect(false, "offline result can be loaded after its commit")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".bak"))
	var capped: Simulation = _new_simulation()
	var capped_seconds: int = service.advance_offline(capped, 40000)
	_expect(capped_seconds == 28800 and is_equal_approx(capped.state.simulated_seconds, 28800.0), "offline reward caps elapsed time at eight hours")


func _test_prestige_reset_and_bonus() -> void:
	var simulation: Simulation = _new_simulation()
	_command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
	simulation.state.money = 900.0
	simulation.state.inventory["wheat"] = 3.0
	simulation.state.cumulative_revenue = 10000.0
	simulation.state.cumulative_production = 777.0
	simulation.state.sound_enabled = false
	var result: CommandResult = _command(simulation, GameCommand.prestige())
	_expect(result.succeeded and simulation.state.prestige_points == 1 and simulation.state.prestige_count == 1, "qualified prestige grants one permanent point")
	_expect(simulation.state.buildings.is_empty() and simulation.state.land_size == 8 and is_equal_approx(simulation.state.money, 500.0) and is_equal_approx(simulation.state.inventory["wheat"], 0.0), "prestige resets land, buildings, inventory, and cash")
	_expect(is_equal_approx(simulation.state.cumulative_revenue, 10000.0) and is_equal_approx(simulation.state.cumulative_production, 777.0) and not simulation.state.sound_enabled, "prestige preserves lifetime progression and sound preference")
	var farm_result: CommandResult = _command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
	var farm_row: Dictionary = simulation.get_snapshot()["buildings"][0]
	_expect(farm_result.succeeded and is_equal_approx(float(farm_row["recipe_rate"]), 0.735), "prestige adds a permanent five-percent production bonus")


func _test_raw_vs_processed_value() -> void:
	var raw_route: Simulation = _new_simulation()
	var flour_route: Simulation = _new_simulation()
	for simulation: Simulation in [raw_route, flour_route]:
		_command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
		_command(simulation, GameCommand.build("market", Vector2i(1, 0)))
	_command(flour_route, GameCommand.build("flour_mill", Vector2i(2, 0)))
	_command(flour_route, GameCommand.build("solar_plant", Vector2i(3, 0)))
	_command(flour_route, GameCommand.set_market_rule("wheat", false, 0.0))
	for _step: int in range(600):
		raw_route.tick(0.1)
		flour_route.tick(0.1)
	_expect(flour_route.state.cumulative_revenue > raw_route.state.cumulative_revenue, "processing wheat into flour earns more than selling the same route raw")
	_expect(raw_route.state.cumulative_revenue > 0.0 and flour_route.state.inventory["flour"] < 0.000001, "both sales routes earn real market revenue")
	print("BALANCE: 60s raw wheat sales $%.1f; flour route $%.1f" % [raw_route.state.cumulative_revenue, flour_route.state.cumulative_revenue])


func _test_upgrade_limits_and_storage() -> void:
	var simulation: Simulation = _new_simulation()
	var farm_result: CommandResult = _command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
	var farm: BuildingInstance = simulation.find_building(farm_result.subject_id)
	var cash_to_restore: float = simulation.state.money
	simulation.state.money = 100.0
	var money_before: float = simulation.state.money
	var failed_upgrade: CommandResult = _command(simulation, GameCommand.upgrade(farm.id))
	_expect(not failed_upgrade.succeeded and farm.level == 1 and simulation.state.money == money_before, "unaffordable upgrade is fully atomic")
	simulation.state.money = cash_to_restore
	var warehouse_result: CommandResult = _command(simulation, GameCommand.build("warehouse", Vector2i(1, 0)))
	_expect(warehouse_result.succeeded and is_equal_approx(simulation.get_storage_capacity(), 3500.0), "warehouse increases the shared storage capacity")
	var warehouse: BuildingInstance = simulation.find_building(warehouse_result.subject_id)
	simulation.state.money = 10000.0
	for _upgrade_index: int in range(4):
		_expect(_command(simulation, GameCommand.upgrade(warehouse.id)).succeeded, "warehouse upgrade succeeds before level five")
	_expect(warehouse.level == 5 and is_equal_approx(simulation.get_storage_capacity(), 9500.0), "warehouse reaches level five with level-based capacity")
	var money_at_cap: float = simulation.state.money
	var capped_upgrade: CommandResult = _command(simulation, GameCommand.upgrade(warehouse.id))
	_expect(not capped_upgrade.succeeded and simulation.state.money == money_at_cap, "level-six upgrade is rejected without spending")


func _test_five_minute_play_and_save_continue() -> void:
	var simulation: Simulation = _new_simulation()
	var farm_result: CommandResult = _command(simulation, GameCommand.build("farm", Vector2i(0, 0)))
	var mill_result: CommandResult = _command(simulation, GameCommand.build("flour_mill", Vector2i(1, 0)))
	var market_result: CommandResult = _command(simulation, GameCommand.build("market", Vector2i(2, 0)))
	var solar_result: CommandResult = _command(simulation, GameCommand.build("solar_plant", Vector2i(3, 0)))
	_expect(farm_result.succeeded and mill_result.succeeded and market_result.succeeded and solar_result.succeeded, "starting funds can launch a powered wheat-to-flour route")
	var first_sale_seconds: float = -1.0
	var first_upgrade_seconds: float = -1.0
	var farm: BuildingInstance = simulation.find_building(farm_result.subject_id)
	for _step: int in range(3000):
		simulation.tick(0.1)
		if first_sale_seconds < 0.0 and simulation.state.cumulative_revenue > 0.0:
			first_sale_seconds = simulation.state.simulated_seconds
		if first_upgrade_seconds < 0.0 and simulation.state.money >= float(simulation.get_upgrade_cost(farm)):
			var upgrade_result: CommandResult = _command(simulation, GameCommand.upgrade(farm.id))
			if upgrade_result.succeeded:
				first_upgrade_seconds = simulation.state.simulated_seconds
	_expect(first_sale_seconds >= 0.0 and first_sale_seconds <= 60.0, "first sale occurs within one simulated minute")
	_expect(first_upgrade_seconds >= 90.0 and first_upgrade_seconds <= 180.0, "first upgrade lands near the two-to-three-minute target")
	_expect(farm.level == 2 and simulation.state.simulated_seconds >= 299.9, "five-minute scenario reaches an upgrade and keeps progressing")
	_expect(simulation.state.storage_used() <= simulation.get_storage_capacity() + 0.000001, "five-minute production respects shared capacity")
	print("BALANCE: first sale %.1fs; first upgrade %.1fs; revenue at 5m $%.1f; storage %.1f/%.1f" % [first_sale_seconds, first_upgrade_seconds, simulation.state.cumulative_revenue, simulation.state.storage_used(), simulation.get_storage_capacity()])
	var service: SaveService = SaveService.new()
	var save_path: String = "res://tests/.tmp_five_minute.json"
	var save_result: Dictionary = service.save_state(simulation.state, save_path)
	_expect(bool(save_result["ok"]), "five-minute game can be saved")
	var loaded: Dictionary = service.load_state(_catalog, save_path)
	_expect(bool(loaded.get("ok", false)), "five-minute save can be resumed")
	if bool(loaded.get("ok", false)):
		var resumed: Simulation = _new_simulation()
		_expect(resumed.restore_state(loaded["state"]), "resumed five-minute state validates")
		for _step: int in range(1000):
			simulation.tick(0.1)
			resumed.tick(0.1)
		_expect(is_equal_approx(simulation.state.money, resumed.state.money), "saved scenario continues deterministically with the same revenue")
		var inventories_match: bool = true
		for resource_id: String in _catalog.resource_ids():
			if not is_equal_approx(float(simulation.state.inventory[resource_id]), float(resumed.state.inventory[resource_id])):
				inventories_match = false
		_expect(inventories_match, "saved scenario continues with the same resource stocks")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".bak"))


func _test_save_round_trip() -> void:
	var simulation: Simulation = _new_simulation()
	_command(simulation, GameCommand.build("farm", Vector2i(2, 3)))
	_command(simulation, GameCommand.build("market", Vector2i(3, 3)))
	_command(simulation, GameCommand.set_market_rule("wheat", true, 2.0))
	for _step: int in range(50):
		simulation.tick(0.1)
	var before: Dictionary = simulation.get_snapshot()
	simulation.state.cumulative_production = 123.5
	simulation.state.prestige_points = 2
	simulation.state.prestige_count = 2
	simulation.state.sound_enabled = false
	var service: SaveService = SaveService.new()
	var save_path: String = "res://tests/.tmp_round_trip.json"
	var save_result: Dictionary = service.save_state(simulation.state, save_path)
	_expect(bool(save_result["ok"]), "save writes to a temporary file and completes")
	var load_result: Dictionary = service.load_state(_catalog, save_path)
	_expect(bool(load_result["ok"]), "valid versioned save loads")
	if not bool(load_result.get("ok", false)):
		printerr("SAVE LOAD: %s" % str(load_result.get("message", "unknown error")))
		return
	var restored: Simulation = _new_simulation()
	_expect(restored.restore_state(load_result["state"]), "loaded state passes simulation validation")
	var after: Dictionary = restored.get_snapshot()
	_expect(is_equal_approx(float(before["money"]), float(after["money"])), "save round trip preserves money")
	_expect(is_equal_approx(restored.state.cumulative_production, 123.5) and restored.state.prestige_points == 2 and restored.state.prestige_count == 2 and not restored.state.sound_enabled, "save round trip preserves progression and sound settings")
	var inventory_matches: bool = true
	for resource_id: String in _catalog.resource_ids():
		if not is_equal_approx(float(before["inventory"][resource_id]), float(after["inventory"][resource_id])):
			inventory_matches = false
	_expect(inventory_matches, "save round trip preserves inventory within float tolerance")
	_expect(before["buildings"].size() == after["buildings"].size(), "save round trip preserves the layout")
	var layout_matches: bool = true
	var before_rows: Array[Dictionary] = before["buildings"]
	var after_rows: Array[Dictionary] = after["buildings"]
	for index: int in range(before_rows.size()):
		if before_rows[index]["cell"] != after_rows[index]["cell"] or before_rows[index]["definition_id"] != after_rows[index]["definition_id"]:
			layout_matches = false
	_expect(layout_matches, "save round trip preserves building types and exact cells")
	var backup_result: Dictionary = service.save_state(simulation.state, save_path)
	_expect(bool(backup_result["ok"]), "second save rotates the previous save to a backup")
	var future_save: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	future_save.store_string("{\"save_version\":99}")
	future_save.close()
	var newer_result: Dictionary = service.load_state(_catalog, save_path)
	var future_read: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	var future_contents: String = future_read.get_as_text()
	future_read.close()
	_expect(bool(newer_result.get("unsupported_newer", false)), "newer unsupported save version is detected")
	_expect(future_contents == "{\"save_version\":99}", "unsupported newer save is left untouched")
	var corrupt_file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	corrupt_file.store_string("not json")
	corrupt_file.close()
	var corrupt_result: Dictionary = service.load_state(_catalog, save_path)
	_expect(bool(corrupt_result["ok"]), "corrupt primary save recovers from the backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".bak"))


func _test_car_production_chain() -> void:
	var simulation: Simulation = _new_simulation()
	simulation.state.money = 100000.0
	for definition_id: String in ["rubber_farm", "tire_factory", "paint_works", "engine_factory", "body_factory", "car_factory"]:
		_expect(_catalog.buildings.has(definition_id), "car chain building exists: %s" % definition_id)
		_expect(_command(simulation, GameCommand.unlock_building(definition_id)).succeeded, "car chain route unlocks with funds: %s" % definition_id)
		_expect(simulation.is_building_unlocked(definition_id), "car chain building unlocks in late game: %s" % definition_id)
	_expect(_catalog.resources.has("car") and _catalog.resources["car"].unit_price == 230.0, "car is the premium end-game good")
	var car_recipe: RecipeDefinition = _catalog.recipes["assemble_car"]
	_expect(car_recipe.inputs.has("engine") and car_recipe.inputs.has("car_body") and car_recipe.inputs.has("tire") and car_recipe.inputs.has("car_paint") and car_recipe.inputs.has("electronics"), "car consumes engine, body, tire, paint and electronics")
	_expect(not simulation.is_building_unlocked("no_such_building"), "unknown building is not unlocked")
	_command(simulation, GameCommand.build("rubber_farm", Vector2i(0, 0)))
	_command(simulation, GameCommand.build("tire_factory", Vector2i(1, 0)))
	_command(simulation, GameCommand.build("solar_plant", Vector2i(2, 0)))
	_command(simulation, GameCommand.build("wind_turbine", Vector2i(3, 0)))
	simulation.tick(0.1)
	_expect(float(simulation.state.inventory.get("rubber", 0.0)) > 0.0, "rubber farm produces raw rubber")
	_expect(is_equal_approx(float(simulation.state.inventory.get("tire", 0.0)), 0.0), "tire factory cannot use same-tick rubber output")
	simulation.tick(0.1)
	_expect(float(simulation.state.inventory.get("tire", 0.0)) > 0.0, "tire factory processes stored rubber on the next tick")
	var full_chain: Simulation = _new_simulation()
	full_chain.state.money = 100000.0
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	var chain_ids: Array[String] = ["iron_mine", "copper_mine", "coal_mine", "gas_well", "sand_quarry", "rubber_farm", "steel_mill", "glassworks", "tire_factory", "paint_works", "cable_factory", "electronics_factory"]
	for unlock_id: String in chain_ids + ["engine_factory", "body_factory"]:
		if not full_chain.is_building_unlocked(unlock_id):
			_command(full_chain, GameCommand.unlock_building(unlock_id))
	for index: int in range(chain_ids.size()):
		_command(full_chain, GameCommand.build(chain_ids[index], cells[index]))
	_command(full_chain, GameCommand.build("engine_factory", Vector2i(4, 1)))
	_command(full_chain, GameCommand.build("body_factory", Vector2i(5, 1)))
	_command(full_chain, GameCommand.build("wind_turbine", Vector2i(6, 1)))
	_command(full_chain, GameCommand.build("wind_turbine", Vector2i(7, 1)))
	for _step: int in range(50):
		full_chain.tick(0.1)
	_expect(float(full_chain.state.inventory.get("engine", 0.0)) > 0.0, "engine factory smelts steel and copper")
	_expect(float(full_chain.state.inventory.get("car_body", 0.0)) > 0.0, "body factory presses steel and glass")


func _test_city_buildings_upgrade_to_ten() -> void:
	var simulation: Simulation = _new_simulation()
	simulation.state.money = 20000.0
	for definition_id: String in ["house", "pine", "oak"]:
		_expect(_catalog.buildings.has(definition_id), "city building exists: %s" % definition_id)
		var definition: BuildingDefinition = _catalog.buildings[definition_id]
		_expect(definition.kind == "decoration" and definition.category == "شهرسازی", "city building is decorative urban development: %s" % definition_id)
		_expect(definition.max_level == 10, "city building grows to level ten: %s" % definition_id)
		_expect(simulation.is_building_unlocked(definition_id), "city buildings need no route unlock: %s" % definition_id)
	var house_result: CommandResult = _command(simulation, GameCommand.build("house", Vector2i(0, 0)))
	_expect(house_result.succeeded, "house builds on an empty cell")
	var house: BuildingInstance = simulation.find_building(house_result.subject_id)
	simulation.state.money = 20000.0
	for _upgrade_index: int in range(9):
		_expect(_command(simulation, GameCommand.upgrade(house.id)).succeeded, "house upgrade succeeds before level ten")
	_expect(house.level == 10, "house reaches level ten and becomes a city")
	_expect(simulation.get_upgrade_cost(house) == 0, "maxed city has no further upgrade cost")
	var money_at_cap: float = simulation.state.money
	var capped_upgrade: CommandResult = _command(simulation, GameCommand.upgrade(house.id))
	_expect(not capped_upgrade.succeeded and simulation.state.money == money_at_cap, "level-eleven upgrade is rejected without spending")
	var pine_result: CommandResult = _command(simulation, GameCommand.build("pine", Vector2i(1, 0)))
	var oak_result: CommandResult = _command(simulation, GameCommand.build("oak", Vector2i(2, 0)))
	_expect(pine_result.succeeded and oak_result.succeeded, "trees build beside the house")
	var snapshot: Dictionary = simulation.get_snapshot()
	var city_levels: Dictionary = {}
	for row: Dictionary in snapshot["buildings"]:
		if str(row["definition_id"]) in ["house", "pine", "oak"]:
			city_levels[str(row["definition_id"])] = int(row["level"])
	_expect(int(city_levels.get("house", 0)) == 10, "snapshot reports the level-ten city")


func _new_simulation() -> Simulation:
	var simulation: Simulation = Simulation.new()
	simulation.initialize(_catalog)
	return simulation


func _command(simulation: Simulation, command: GameCommand) -> CommandResult:
	simulation.enqueue_command(command)
	var results: Array[CommandResult] = simulation.process_commands()
	return results[0]


func _errors_contain(catalog: GameCatalog, fragment: String) -> bool:
	for message: String in catalog.errors:
		if message.contains(fragment):
			return true
	return false


func _expect(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		printerr("FAIL: %s" % description)
		_failures += 1
