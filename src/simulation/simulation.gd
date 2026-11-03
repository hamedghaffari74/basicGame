class_name Simulation
extends RefCounted

const EPSILON: float = 0.000001

var catalog: GameCatalog
var state: GameState = GameState.new()
var income_per_second: float = 0.0
var tick_count: int = 0
var power_generated_per_second: float = 0.0
var power_demand_per_second: float = 0.0
var power_ratio: float = 1.0
var battery_energy_stored: float = 0.0
var battery_energy_capacity: float = 0.0
var power_shortage: bool = false
var _command_queue: Array[GameCommand] = []


func initialize(game_catalog: GameCatalog) -> void:
	catalog = game_catalog
	state = GameState.new()
	state.configure(catalog.resource_ids(), catalog.balance.initial_money, catalog.balance.initial_land_size, catalog.balance.initial_storage_capacity, catalog.market_sell_defaults())
	_initialize_free_buildings()
	income_per_second = 0.0
	tick_count = 0
	power_generated_per_second = 0.0
	power_demand_per_second = 0.0
	power_ratio = 1.0
	battery_energy_stored = 0.0
	battery_energy_capacity = 0.0
	power_shortage = false
	_command_queue.clear()


func enqueue_command(command: GameCommand) -> void:
	_command_queue.append(command)


func process_commands() -> Array[CommandResult]:
	var results: Array[CommandResult] = []
	while not _command_queue.is_empty():
		var command: GameCommand = _command_queue.pop_front()
		results.append(_apply_command(command))
	return results


func tick(delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return
	_step_production(delta_seconds)
	_step_market(delta_seconds)
	state.simulated_seconds += delta_seconds
	tick_count += 1


func find_building_at(cell: Vector2i) -> BuildingInstance:
	for building: BuildingInstance in state.buildings:
		if building.cell == cell:
			return building
	return null


func find_building(building_id: int) -> BuildingInstance:
	for building: BuildingInstance in state.buildings:
		if building.id == building_id:
			return building
	return null


func get_storage_capacity() -> float:
	var capacity: float = state.initial_storage_capacity
	for building: BuildingInstance in state.buildings:
		var definition: BuildingDefinition = catalog.buildings.get(building.definition_id)
		if definition != null and definition.kind == "storage":
			capacity += definition.storage_capacity * float(building.level)
	return capacity


func get_upgrade_cost(building: BuildingInstance) -> int:
	if building == null or not catalog.buildings.has(building.definition_id):
		return 0
	var definition: BuildingDefinition = catalog.buildings[building.definition_id]
	if building.level >= definition.max_level:
		return 0
	var multiplier: float = definition.upgrade_base_multiplier + float(building.level - 1) * definition.upgrade_level_increment
	return int(ceil(definition.build_cost * multiplier))


func get_demolition_refund(building: BuildingInstance) -> float:
	if building == null or not catalog.buildings.has(building.definition_id):
		return 0.0
	var definition: BuildingDefinition = catalog.buildings[building.definition_id]
	return definition.build_cost * definition.refund_rate


func get_snapshot() -> Dictionary:
	var building_rows: Array[Dictionary] = []
	var snapshot_battery_energy: float = 0.0
	var snapshot_battery_capacity: float = 0.0
	for building: BuildingInstance in state.buildings:
		if not catalog.buildings.has(building.definition_id):
			continue
		var definition: BuildingDefinition = catalog.buildings[building.definition_id]
		var recipe_inputs: Dictionary[String, float] = {}
		var recipe_outputs: Dictionary[String, float] = {}
		var recipe_rate: float = 0.0
		if definition.kind == "producer" and catalog.recipes.has(definition.recipe_id):
			var recipe: RecipeDefinition = catalog.recipes[definition.recipe_id]
			recipe_inputs = recipe.inputs.duplicate()
			recipe_outputs = recipe.outputs.duplicate()
			recipe_rate = recipe.output_per_second * _building_rate_multiplier(building)
		if definition.kind == "battery":
			snapshot_battery_energy += building.energy_stored
			snapshot_battery_capacity += definition.battery_capacity * float(building.level)
		building_rows.append({
			"id": building.id,
			"definition_id": definition.id,
			"name_fa": definition.name_fa,
			"category": definition.category,
			"kind": definition.kind,
			"glyph": definition.glyph,
			"color": definition.color_hex,
			"cell": building.cell,
			"level": building.level,
			"max_level": definition.max_level,
			"build_cost": definition.build_cost,
			"upgrade_cost": get_upgrade_cost(building),
			"refund": get_demolition_refund(building),
			"status": building.status,
			"description_fa": definition.description_fa,
			"tier": definition.tier,
			"neighbor_bonus": get_neighbor_bonus(building),
			"neighbor_details": get_neighbor_details(building),
			"affected_neighbors": get_affected_neighbors(building),
			"recipe_inputs": recipe_inputs,
			"recipe_outputs": recipe_outputs,
			"recipe_rate": recipe_rate,
			"last_inputs": building.last_inputs.duplicate(),
			"last_outputs": building.last_outputs.duplicate(),
			"storage_capacity": definition.storage_capacity * float(building.level),
			"market_rate_per_second": definition.market_rate_per_second * float(building.level),
			"power_output_per_second": definition.power_output_per_second * _building_rate_multiplier(building),
			"power_demand_per_second": definition.power_demand_per_second,
			"fuel_resource_id": definition.fuel_resource_id,
			"battery_energy": building.energy_stored,
			"battery_capacity": definition.battery_capacity * float(building.level)
		})
	return {
		"money": state.money,
		"income_per_second": income_per_second,
		"land_size": state.land_size,
		"inventory": state.inventory.duplicate(),
		"market_rules": state.market_rules.duplicate(true),
		"unlocked_buildings": state.unlocked_buildings.duplicate(),
		"storage_used": state.storage_used(),
		"storage_capacity": get_storage_capacity(),
		"buildings": building_rows,
		"simulated_seconds": state.simulated_seconds,
		"cumulative_revenue": state.cumulative_revenue,
		"cumulative_production": state.cumulative_production,
		"prestige_points": state.prestige_points,
		"prestige_count": state.prestige_count,
		"prestige_bonus": _prestige_bonus(),
		"prestige_requirement": get_prestige_requirement(),
		"sound_enabled": state.sound_enabled,
		"current_tier": get_current_tier(),
		"tick_count": tick_count,
		"market_count": _market_count(),
		"shop_count": _shop_count(),
		"power_generated_per_second": power_generated_per_second,
		"power_demand_per_second": power_demand_per_second,
		"power_ratio": power_ratio,
		"power_shortage": power_shortage,
		"battery_energy_stored": snapshot_battery_energy,
		"battery_energy_capacity": snapshot_battery_capacity
	}


func restore_state(candidate: GameState) -> bool:
	if candidate == null or candidate.land_size < catalog.balance.initial_land_size or candidate.land_size > catalog.balance.maximum_land_size:
		return false
	if not is_finite(candidate.money) or candidate.money < 0.0 or not is_finite(candidate.initial_storage_capacity) or candidate.initial_storage_capacity <= 0.0:
		return false
	var seen_cells: Dictionary[Vector2i, bool] = {}
	var seen_ids: Dictionary[int, bool] = {}
	var max_id: int = 0
	var candidate_capacity: float = candidate.initial_storage_capacity
	for building_id_value: Variant in candidate.unlocked_buildings:
		var unlocked_building_id: String = str(building_id_value)
		if not catalog.buildings.has(unlocked_building_id) or typeof(candidate.unlocked_buildings[building_id_value]) != TYPE_BOOL:
			return false
	for definition: BuildingDefinition in catalog.buildings.values():
		if definition.tier <= 1 and not bool(candidate.unlocked_buildings.get(definition.id, false)):
			return false
	for building: BuildingInstance in candidate.buildings:
		if building.id <= 0 or seen_ids.has(building.id) or not catalog.buildings.has(building.definition_id):
			return false
		var definition: BuildingDefinition = catalog.buildings[building.definition_id]
		if not is_finite(building.energy_stored) or building.energy_stored < -catalog.balance.production_tolerance:
			return false
		if definition.kind == "battery":
			if building.energy_stored > definition.battery_capacity * float(building.level) + catalog.balance.production_tolerance:
				return false
		elif building.energy_stored > catalog.balance.production_tolerance:
			return false
		if building.cell.x < 0 or building.cell.y < 0 or building.cell.x >= candidate.land_size or building.cell.y >= candidate.land_size:
			return false
		if building.level < 1 or building.level > definition.max_level or seen_cells.has(building.cell):
			return false
		seen_cells[building.cell] = true
		seen_ids[building.id] = true
		max_id = maxi(max_id, building.id)
		if definition.kind == "storage":
			candidate_capacity += definition.storage_capacity * float(building.level)
	for resource_id: String in catalog.resource_ids():
		if not candidate.inventory.has(resource_id) or not is_finite(float(candidate.inventory[resource_id])) or candidate.inventory[resource_id] < -catalog.balance.production_tolerance:
			return false
		if not candidate.market_rules.has(resource_id):
			return false
		var rule: Dictionary = candidate.market_rules[resource_id]
		var minimum_stock: Variant = rule.get("minimum_stock", null)
		if typeof(rule.get("enabled", null)) != TYPE_BOOL or not _is_number(minimum_stock) or float(minimum_stock) < 0.0:
			return false
	for resource_id: String in candidate.inventory:
		if not catalog.resources.has(resource_id):
			return false
	var inventory_total: float = candidate.storage_used()
	if inventory_total > candidate_capacity + catalog.balance.production_tolerance:
		return false
	if not is_finite(candidate.simulated_seconds) or candidate.simulated_seconds < 0.0 or not is_finite(candidate.cumulative_revenue) or candidate.cumulative_revenue < 0.0 or not is_finite(candidate.cumulative_production) or candidate.cumulative_production < 0.0 or candidate.prestige_points < 0 or candidate.prestige_count < 0:
		return false
	if candidate.next_building_id <= max_id:
		candidate.next_building_id = max_id + 1
	state = candidate
	income_per_second = 0.0
	power_generated_per_second = 0.0
	power_demand_per_second = 0.0
	power_ratio = 1.0
	battery_energy_stored = 0.0
	battery_energy_capacity = 0.0
	power_shortage = false
	_command_queue.clear()
	return true


func _apply_command(command: GameCommand) -> CommandResult:
	match command.kind:
		GameCommand.Kind.BUILD:
			return _build(command)
		GameCommand.Kind.DEMOLISH:
			return _demolish(command)
		GameCommand.Kind.UPGRADE:
			return _upgrade(command)
		GameCommand.Kind.SET_MARKET_RULE:
			return _set_market_rule(command)
		GameCommand.Kind.SELL_RESOURCE:
			return _sell_resource(command)
		GameCommand.Kind.EXPAND_LAND:
			return _expand_land()
		GameCommand.Kind.PRESTIGE:
			return _prestige()
		GameCommand.Kind.UNLOCK_BUILDING:
			return _unlock_building(command)
	return CommandResult.new(false, "unknown_command", "فرمان ناشناخته است.")


func _build(command: GameCommand) -> CommandResult:
	if not catalog.buildings.has(command.definition_id):
		return CommandResult.new(false, "unknown_building", "این ساختمان در داده‌های بازی وجود ندارد.")
	var definition: BuildingDefinition = catalog.buildings[command.definition_id]
	if not is_building_unlocked(definition.id):
		return CommandResult.new(false, "building_locked", "ابتدا مسیر %s را از پنل مسیر تولید با پرداخت $%s باز کن." % [definition.name_fa, _format_money(definition.unlock_cost)])
	if command.cell.x < 0 or command.cell.y < 0 or command.cell.x >= state.land_size or command.cell.y >= state.land_size:
		return CommandResult.new(false, "outside_land", "این خانه بیرون زمین است.")
	if find_building_at(command.cell) != null:
		return CommandResult.new(false, "occupied", "این خانه قبلاً ساختمان دارد.")
	if state.money + EPSILON < definition.build_cost:
		return CommandResult.new(false, "insufficient_funds", "پول کافی نیست.")
	var building: BuildingInstance = BuildingInstance.new()
	building.id = state.next_building_id
	building.definition_id = definition.id
	building.cell = command.cell
	state.money -= definition.build_cost
	state.next_building_id += 1
	state.buildings.append(building)
	return CommandResult.new(true, "built", "%s ساخته شد." % definition.name_fa, building.id)


func _unlock_building(command: GameCommand) -> CommandResult:
	if not catalog.buildings.has(command.definition_id):
		return CommandResult.new(false, "unknown_building", "این ساختمان در داده‌های بازی وجود ندارد.")
	var definition: BuildingDefinition = catalog.buildings[command.definition_id]
	if definition.tier <= 1:
		return CommandResult.new(false, "already_unlocked", "ساختمان‌های Tier 1 از ابتدا باز هستند.")
	if is_building_unlocked(definition.id):
		return CommandResult.new(false, "already_unlocked", "مسیر %s قبلاً باز شده است." % definition.name_fa)
	if state.money + EPSILON < definition.unlock_cost:
		return CommandResult.new(false, "insufficient_funds", "برای بازکردن مسیر %s به $%s نیاز داری." % [definition.name_fa, _format_money(definition.unlock_cost)])
	state.money -= definition.unlock_cost
	state.unlocked_buildings[definition.id] = true
	return CommandResult.new(true, "building_unlocked", "مسیر %s با پرداخت $%s باز شد؛ هزینهٔ ساخت آن جداگانه محاسبه می‌شود." % [definition.name_fa, _format_money(definition.unlock_cost)])


func _demolish(command: GameCommand) -> CommandResult:
	var building: BuildingInstance = find_building(command.building_id)
	if building == null:
		return CommandResult.new(false, "missing_building", "ساختمان برای حذف پیدا نشد.")
	var definition: BuildingDefinition = catalog.buildings[building.definition_id]
	if definition.kind == "storage":
		var reduced_capacity: float = get_storage_capacity() - definition.storage_capacity * float(building.level)
		if state.storage_used() > reduced_capacity + catalog.balance.production_tolerance:
			return CommandResult.new(false, "storage_in_use", "ابتدا کالاها را بفروش یا مصرف کن؛ حذف این انبار ظرفیت را از موجودی فعلی کمتر می‌کند.")
	var refund: float = get_demolition_refund(building)
	state.money += refund
	state.buildings.erase(building)
	return CommandResult.new(true, "demolished", "%s حذف شد؛ $%s بازپرداخت شد." % [definition.name_fa, _format_money(refund)])


func _upgrade(command: GameCommand) -> CommandResult:
	var building: BuildingInstance = find_building(command.building_id)
	if building == null:
		return CommandResult.new(false, "missing_building", "ساختمان برای ارتقا پیدا نشد.")
	var definition: BuildingDefinition = catalog.buildings[building.definition_id]
	if building.level >= definition.max_level:
		return CommandResult.new(false, "max_level", "ساختمان به بالاترین سطح رسیده است.")
	var cost: int = get_upgrade_cost(building)
	if state.money + EPSILON < float(cost):
		return CommandResult.new(false, "insufficient_funds", "برای این ارتقا پول کافی نیست.")
	state.money -= float(cost)
	building.level += 1
	return CommandResult.new(true, "upgraded", "%s به سطح %d رسید." % [definition.name_fa, building.level], building.id)


func _set_market_rule(command: GameCommand) -> CommandResult:
	if not state.market_rules.has(command.resource_id) or not catalog.resources.has(command.resource_id):
		return CommandResult.new(false, "unknown_resource", "این کالا در انبار تعریف نشده است.")
	if command.minimum_stock < 0.0:
		return CommandResult.new(false, "invalid_minimum", "حداقل ذخیره نمی‌تواند منفی باشد.")
	state.market_rules[command.resource_id] = {
		"enabled": command.sell_enabled,
		"minimum_stock": command.minimum_stock
	}
	return CommandResult.new(true, "market_rule_changed", "قانون فروش %s به‌روز شد." % catalog.resources[command.resource_id].name_fa)


func _sell_resource(command: GameCommand) -> CommandResult:
	if _shop_count() <= 0:
		return CommandResult.new(false, "shop_required", "برای فروش دستی، ابتدا فروشگاه بساز.")
	if not catalog.resources.has(command.resource_id):
		return CommandResult.new(false, "unknown_resource", "این کالا در انبار تعریف نشده است.")
	var quantity: float = float(state.inventory.get(command.resource_id, 0.0))
	if quantity <= EPSILON:
		return CommandResult.new(false, "no_stock", "از %s چیزی برای فروش در انبار نیست." % catalog.resources[command.resource_id].name_fa)
	var revenue: float = quantity * catalog.resources[command.resource_id].unit_price
	state.inventory[command.resource_id] = 0.0
	state.money += revenue
	state.cumulative_revenue += revenue
	return CommandResult.new(true, "manual_sale", "فروشگاه %s واحد %s را فروخت؛ $%s اضافه شد." % [String.num(quantity, 2), catalog.resources[command.resource_id].name_fa, _format_money(revenue)])


func _expand_land() -> CommandResult:
	for step: Dictionary in catalog.balance.expansion_steps:
		var target_size: int = int(step["size"])
		if target_size <= state.land_size:
			continue
		if state.cumulative_revenue + EPSILON < float(step["revenue"]):
			return CommandResult.new(false, "expansion_revenue_locked", "برای گسترش به %d×%d، درآمد تجمعی $%s لازم است." % [target_size, target_size, _format_money(float(step["revenue"]))])
		if state.money + EPSILON < float(step["cost"]):
			return CommandResult.new(false, "insufficient_funds", "گسترش زمین به $%s نیاز دارد." % _format_money(float(step["cost"])))
		state.money -= float(step["cost"])
		state.land_size = target_size
		return CommandResult.new(true, "land_expanded", "زمین به %d×%d گسترش یافت." % [target_size, target_size])
	return CommandResult.new(false, "maximum_land", "زمین به بیشترین اندازه رسیده است.")


func _prestige() -> CommandResult:
	var requirement: float = get_prestige_requirement()
	if state.cumulative_revenue + EPSILON < requirement:
		return CommandResult.new(false, "prestige_locked", "برای پرستیژ به درآمد تجمعی $%s نیاز داری." % _format_money(requirement))
	var preserved_revenue: float = state.cumulative_revenue
	var preserved_production: float = state.cumulative_production
	var preserved_points: int = state.prestige_points + 1
	var preserved_count: int = state.prestige_count + 1
	var preserved_sound: bool = state.sound_enabled
	state.configure(catalog.resource_ids(), catalog.balance.initial_money, catalog.balance.initial_land_size, catalog.balance.initial_storage_capacity, catalog.market_sell_defaults())
	_initialize_free_buildings()
	state.cumulative_revenue = preserved_revenue
	state.cumulative_production = preserved_production
	state.prestige_points = preserved_points
	state.prestige_count = preserved_count
	state.sound_enabled = preserved_sound
	tick_count = 0
	income_per_second = 0.0
	power_generated_per_second = 0.0
	power_demand_per_second = 0.0
	power_ratio = 1.0
	battery_energy_stored = 0.0
	battery_energy_capacity = 0.0
	power_shortage = false
	return CommandResult.new(true, "prestige_completed", "پرستیژ انجام شد؛ زمین و دارایی بازنشانی شد و پاداش دائمی تولید افزایش یافت.")


func _step_production(delta_seconds: float) -> void:
	var producers: Array[BuildingInstance] = []
	for building: BuildingInstance in state.buildings:
		building.last_inputs.clear()
		building.last_outputs.clear()
		if catalog.buildings[building.definition_id].kind == "producer":
			producers.append(building)
	producers.sort_custom(func(left: BuildingInstance, right: BuildingInstance) -> bool: return left.id < right.id)
	var demand_energy: float = _estimate_active_power_demand(producers, delta_seconds)
	_dispatch_power(demand_energy, delta_seconds)
	var deferred_outputs: Dictionary[String, float] = {}
	var reserved_output_units: float = 0.0
	var capacity: float = get_storage_capacity()
	for building: BuildingInstance in producers:
		var definition: BuildingDefinition = catalog.buildings[building.definition_id]
		var recipe: RecipeDefinition = catalog.recipes[definition.recipe_id]
		var requested_output: float = recipe.output_per_second * _building_rate_multiplier(building) * delta_seconds
		if definition.power_demand_per_second > 0.0:
			requested_output *= power_ratio
		var possible_by_input: float = requested_output
		var total_inputs_per_output: float = 0.0
		var total_outputs_per_output: float = 0.0
		for input_id: String in recipe.inputs:
			var input_ratio: float = recipe.inputs[input_id]
			total_inputs_per_output += input_ratio
			var available_input: float = float(state.inventory.get(input_id, 0.0))
			possible_by_input = minf(possible_by_input, available_input / input_ratio)
		for output_ratio: float in recipe.outputs.values():
			total_outputs_per_output += output_ratio
		var possible_by_storage: float = requested_output
		var net_storage_per_output: float = total_outputs_per_output - total_inputs_per_output
		if net_storage_per_output > catalog.balance.production_tolerance:
			var available_storage: float = maxf(0.0, capacity - state.storage_used() - reserved_output_units)
			possible_by_storage = available_storage / net_storage_per_output
		var actual_output: float = minf(requested_output, minf(possible_by_input, possible_by_storage))
		if actual_output <= catalog.balance.production_tolerance:
			if definition.power_demand_per_second > 0.0 and power_ratio <= catalog.balance.production_tolerance and _producer_can_run(building, recipe, delta_seconds):
				building.status = "power_shortage"
			elif not recipe.inputs.is_empty() and possible_by_input <= catalog.balance.production_tolerance:
				building.status = "no_input"
			else:
				building.status = "storage_full"
			continue
		for input_id: String in recipe.inputs:
			var consumed: float = actual_output * recipe.inputs[input_id]
			state.inventory[input_id] = maxf(0.0, float(state.inventory.get(input_id, 0.0)) - consumed)
			building.last_inputs[input_id] = consumed
		for output_id: String in recipe.outputs:
			var produced: float = actual_output * recipe.outputs[output_id]
			state.cumulative_production += produced
			deferred_outputs[output_id] = float(deferred_outputs.get(output_id, 0.0)) + produced
			building.last_outputs[output_id] = produced
			reserved_output_units += produced
		if definition.power_demand_per_second > 0.0 and power_ratio < 1.0 - catalog.balance.production_tolerance and possible_by_input + catalog.balance.production_tolerance >= requested_output and possible_by_storage + catalog.balance.production_tolerance >= requested_output:
			building.status = "power_limited"
		elif possible_by_input + catalog.balance.production_tolerance < requested_output:
			building.status = "limited_input"
		elif possible_by_storage + catalog.balance.production_tolerance < requested_output:
			building.status = "storage_full"
		else:
			building.status = "operational"
	for resource_id: String in deferred_outputs:
		state.inventory[resource_id] = float(state.inventory.get(resource_id, 0.0)) + deferred_outputs[resource_id]


func _estimate_active_power_demand(producers: Array[BuildingInstance], delta_seconds: float) -> float:
	var planned_inventory: Dictionary[String, float] = state.inventory.duplicate()
	var reserved_outputs: float = 0.0
	var capacity: float = get_storage_capacity()
	var demand_energy: float = 0.0
	for building: BuildingInstance in producers:
		var definition: BuildingDefinition = catalog.buildings[building.definition_id]
		var recipe: RecipeDefinition = catalog.recipes[definition.recipe_id]
		var requested_output: float = recipe.output_per_second * _building_rate_multiplier(building) * delta_seconds
		var possible_by_input: float = requested_output
		var total_input_units: float = 0.0
		var total_output_units: float = 0.0
		for input_id: String in recipe.inputs:
			var input_ratio: float = recipe.inputs[input_id]
			total_input_units += input_ratio
			possible_by_input = minf(possible_by_input, float(planned_inventory.get(input_id, 0.0)) / input_ratio)
		for output_ratio: float in recipe.outputs.values():
			total_output_units += output_ratio
		var possible_by_storage: float = requested_output
		var net_storage_per_output: float = total_output_units - total_input_units
		if net_storage_per_output > catalog.balance.production_tolerance:
			var available_storage: float = maxf(0.0, capacity - _inventory_total(planned_inventory) - reserved_outputs)
			possible_by_storage = available_storage / net_storage_per_output
		var actual_output: float = minf(requested_output, minf(possible_by_input, possible_by_storage))
		if actual_output <= catalog.balance.production_tolerance:
			continue
		if definition.power_demand_per_second > 0.0:
			demand_energy += definition.power_demand_per_second * delta_seconds
		for input_id: String in recipe.inputs:
			planned_inventory[input_id] = maxf(0.0, float(planned_inventory.get(input_id, 0.0)) - actual_output * recipe.inputs[input_id])
		for output_ratio: float in recipe.outputs.values():
			reserved_outputs += actual_output * output_ratio
	return demand_energy


func _dispatch_power(demand_energy: float, delta_seconds: float) -> void:
	var renewable_sources: Array[BuildingInstance] = []
	var fuel_sources: Array[BuildingInstance] = []
	var batteries: Array[BuildingInstance] = []
	for building: BuildingInstance in state.buildings:
		var definition: BuildingDefinition = catalog.buildings[building.definition_id]
		if definition.kind == "power":
			if definition.fuel_resource_id.is_empty():
				renewable_sources.append(building)
			else:
				fuel_sources.append(building)
		elif definition.kind == "battery":
			batteries.append(building)
	renewable_sources.sort_custom(func(left: BuildingInstance, right: BuildingInstance) -> bool: return left.id < right.id)
	fuel_sources.sort_custom(func(left: BuildingInstance, right: BuildingInstance) -> bool: return left.id < right.id)
	batteries.sort_custom(func(left: BuildingInstance, right: BuildingInstance) -> bool: return left.id < right.id)
	var renewable_energy: float = 0.0
	for building: BuildingInstance in renewable_sources:
		var definition: BuildingDefinition = catalog.buildings[building.definition_id]
		var generated: float = definition.power_output_per_second * _building_rate_multiplier(building) * delta_seconds
		renewable_energy += generated
		building.status = "operational"
		building.last_outputs["power"] = generated
	var remaining_demand: float = maxf(0.0, demand_energy - renewable_energy)
	var fuel_generated: float = 0.0
	for building: BuildingInstance in fuel_sources:
		var definition: BuildingDefinition = catalog.buildings[building.definition_id]
		if remaining_demand <= catalog.balance.production_tolerance:
			building.status = "standby"
			continue
		var available_fuel: float = float(state.inventory.get(definition.fuel_resource_id, 0.0))
		if available_fuel <= catalog.balance.production_tolerance:
			building.status = "out_of_fuel"
			continue
		var generator_capacity: float = definition.power_output_per_second * _building_rate_multiplier(building) * delta_seconds
		var possible_from_fuel: float = available_fuel / definition.fuel_per_energy
		var generated_energy: float = minf(remaining_demand, minf(generator_capacity, possible_from_fuel))
		var consumed_fuel: float = generated_energy * definition.fuel_per_energy
		state.inventory[definition.fuel_resource_id] = maxf(0.0, available_fuel - consumed_fuel)
		building.last_inputs[definition.fuel_resource_id] = consumed_fuel
		building.last_outputs["power"] = generated_energy
		building.status = "operational" if generated_energy > catalog.balance.production_tolerance else "out_of_fuel"
		fuel_generated += generated_energy
		remaining_demand -= generated_energy
	var battery_discharged: float = 0.0
	if remaining_demand > catalog.balance.production_tolerance:
		for building: BuildingInstance in batteries:
			var definition: BuildingDefinition = catalog.buildings[building.definition_id]
			var discharge_limit: float = definition.battery_discharge_per_second * float(building.level) * delta_seconds
			var discharged: float = minf(remaining_demand, minf(discharge_limit, building.energy_stored))
			building.energy_stored = maxf(0.0, building.energy_stored - discharged)
			if discharged > catalog.balance.production_tolerance:
				building.last_outputs["power"] = discharged
				building.status = "discharging"
				battery_discharged += discharged
				remaining_demand -= discharged
			else:
				building.status = "standby"
	else:
		var renewable_surplus: float = maxf(0.0, renewable_energy - demand_energy)
		for building: BuildingInstance in batteries:
			var definition: BuildingDefinition = catalog.buildings[building.definition_id]
			var battery_capacity: float = definition.battery_capacity * float(building.level)
			var charge_limit: float = definition.battery_charge_per_second * float(building.level) * delta_seconds
			var charge: float = minf(renewable_surplus, minf(charge_limit, maxf(0.0, battery_capacity - building.energy_stored)))
			building.energy_stored = minf(battery_capacity, building.energy_stored + charge)
			if charge > catalog.balance.production_tolerance:
				building.last_inputs["power"] = charge
				building.status = "charging"
				renewable_surplus -= charge
			else:
				building.status = "standby"
	var supplied_energy: float = renewable_energy + fuel_generated + battery_discharged
	power_generated_per_second = (renewable_energy + fuel_generated) / delta_seconds
	power_demand_per_second = demand_energy / delta_seconds
	power_ratio = 1.0 if demand_energy <= catalog.balance.production_tolerance else clampf(supplied_energy / demand_energy, 0.0, 1.0)
	power_shortage = demand_energy > catalog.balance.production_tolerance and supplied_energy + catalog.balance.production_tolerance < demand_energy
	battery_energy_stored = 0.0
	battery_energy_capacity = 0.0
	for building: BuildingInstance in batteries:
		var definition: BuildingDefinition = catalog.buildings[building.definition_id]
		battery_energy_stored += building.energy_stored
		battery_energy_capacity += definition.battery_capacity * float(building.level)


func _inventory_total(inventory: Dictionary[String, float]) -> float:
	var total: float = 0.0
	for amount: float in inventory.values():
		total += amount
	return total


func _producer_can_run(building: BuildingInstance, recipe: RecipeDefinition, delta_seconds: float) -> bool:
	var possible_by_input: float = recipe.output_per_second * _building_rate_multiplier(building) * delta_seconds
	var total_input_units: float = 0.0
	var total_output_units: float = 0.0
	for input_id: String in recipe.inputs:
		var input_ratio: float = recipe.inputs[input_id]
		total_input_units += input_ratio
		possible_by_input = minf(possible_by_input, float(state.inventory.get(input_id, 0.0)) / input_ratio)
	for output_ratio: float in recipe.outputs.values():
		total_output_units += output_ratio
	var net_storage: float = total_output_units - total_input_units
	if net_storage > catalog.balance.production_tolerance:
		possible_by_input = minf(possible_by_input, maxf(0.0, get_storage_capacity() - state.storage_used()) / net_storage)
	return possible_by_input > catalog.balance.production_tolerance


func _step_market(delta_seconds: float) -> void:
	var earnings: float = 0.0
	if _market_count() > 0:
		for resource_id: String in catalog.resource_ids():
			var rule: Dictionary = state.market_rules.get(resource_id, {})
			if not bool(rule.get("enabled", false)):
				continue
			var minimum_stock: float = maxf(0.0, float(rule.get("minimum_stock", 0.0)))
			var sellable: float = maxf(0.0, float(state.inventory.get(resource_id, 0.0)) - minimum_stock)
			if sellable <= EPSILON:
				continue
			state.inventory[resource_id] = maxf(0.0, float(state.inventory[resource_id]) - sellable)
			earnings += sellable * catalog.resources[resource_id].unit_price
	state.money += earnings
	state.cumulative_revenue += earnings
	income_per_second = earnings / delta_seconds


func _market_count() -> int:
	var count: int = 0
	for building: BuildingInstance in state.buildings:
		if catalog.buildings[building.definition_id].kind == "market":
			count += 1
	return count


func _shop_count() -> int:
	var count: int = 0
	for building: BuildingInstance in state.buildings:
		if catalog.buildings[building.definition_id].kind == "shop":
			count += 1
	return count


func is_tier_unlocked(tier: int) -> bool:
	if tier <= 1:
		return true
	if tier == 2:
		return state.cumulative_revenue >= catalog.balance.tier_two_revenue or state.cumulative_production >= catalog.balance.tier_two_production
	return state.cumulative_revenue >= catalog.balance.tier_three_revenue or state.cumulative_production >= catalog.balance.tier_three_production


func is_building_unlocked(building_id: String) -> bool:
	if not catalog.buildings.has(building_id):
		return false
	var definition: BuildingDefinition = catalog.buildings[building_id]
	return definition.tier <= 1 or bool(state.unlocked_buildings.get(building_id, false))


func _initialize_free_buildings() -> void:
	state.unlocked_buildings.clear()
	for definition: BuildingDefinition in catalog.buildings.values():
		if definition.tier <= 1:
			state.unlocked_buildings[definition.id] = true


func get_current_tier() -> int:
	if is_tier_unlocked(3):
		return 3
	if is_tier_unlocked(2):
		return 2
	return 1


func get_prestige_requirement() -> float:
	return catalog.balance.prestige_base_revenue * float(state.prestige_count + 1)


func get_next_expansion() -> Dictionary:
	for step: Dictionary in catalog.balance.expansion_steps:
		if int(step["size"]) > state.land_size:
			return step.duplicate()
	return {}


func get_neighbor_bonus(building: BuildingInstance) -> float:
	if building == null or not catalog.buildings.has(building.definition_id):
		return 0.0
	var bonus: float = 0.0
	for detail: Dictionary in get_neighbor_details(building):
		bonus += float(detail.get("bonus", 0.0))
	return minf(bonus, catalog.balance.neighbor_bonus_cap)


func get_neighbor_details(building: BuildingInstance) -> Array[Dictionary]:
	var details: Array[Dictionary] = []
	if building == null:
		return details
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var target_definition: BuildingDefinition = catalog.buildings[building.definition_id]
	for offset: Vector2i in offsets:
		var neighbor: BuildingInstance = find_building_at(building.cell + offset)
		if neighbor == null or not catalog.buildings.has(neighbor.definition_id):
			continue
		var source_definition: BuildingDefinition = catalog.buildings[neighbor.definition_id]
		for effect: Dictionary in source_definition.neighbor_effects:
			var kind_match: bool = str(effect.get("target_kind", "")).is_empty() or str(effect["target_kind"]) == target_definition.kind
			var category_match: bool = str(effect.get("target_category", "")).is_empty() or str(effect["target_category"]) == target_definition.category
			if kind_match and category_match:
				details.append({"source_name": source_definition.name_fa, "bonus": float(effect["bonus"]), "cell": neighbor.cell})
	return details


func get_affected_neighbors(source: BuildingInstance) -> Array[Dictionary]:
	var affected: Array[Dictionary] = []
	if source == null or not catalog.buildings.has(source.definition_id):
		return affected
	var source_definition: BuildingDefinition = catalog.buildings[source.definition_id]
	if source_definition.neighbor_effects.is_empty():
		return affected
	for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: BuildingInstance = find_building_at(source.cell + offset)
		if neighbor == null or not catalog.buildings.has(neighbor.definition_id):
			continue
		var target_definition: BuildingDefinition = catalog.buildings[neighbor.definition_id]
		for effect: Dictionary in source_definition.neighbor_effects:
			var kind_match: bool = str(effect.get("target_kind", "")).is_empty() or str(effect["target_kind"]) == target_definition.kind
			var category_match: bool = str(effect.get("target_category", "")).is_empty() or str(effect["target_category"]) == target_definition.category
			if kind_match and category_match:
				affected.append({"target_name": target_definition.name_fa, "bonus": float(effect["bonus"]), "cell": neighbor.cell})
	return affected


func _building_rate_multiplier(building: BuildingInstance) -> float:
	var definition: BuildingDefinition = catalog.buildings[building.definition_id]
	var level_bonus: float = 1.0 + float(building.level - 1) * definition.rate_per_level_increment
	return level_bonus * (1.0 + _prestige_bonus()) * (1.0 + get_neighbor_bonus(building))


func _prestige_bonus() -> float:
	return minf(float(state.prestige_points) * catalog.balance.prestige_bonus_per_point, catalog.balance.prestige_bonus_cap)


func _format_money(amount: float) -> String:
	return "%.0f" % amount


func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))
