class_name GameState
extends RefCounted

var money: float = 0.0
var land_size: int = 8
var initial_storage_capacity: float = 40.0
var inventory: Dictionary[String, float] = {}
var market_rules: Dictionary[String, Dictionary] = {}
var buildings: Array[BuildingInstance] = []
var next_building_id: int = 1
var simulated_seconds: float = 0.0
var cumulative_revenue: float = 0.0
var cumulative_production: float = 0.0
var prestige_points: int = 0
var prestige_count: int = 0
var sound_enabled: bool = true


func configure(resource_ids: Array[String], starting_money: float, starting_land_size: int, starting_capacity: float, market_sell_defaults: Dictionary = {}) -> void:
	inventory.clear()
	market_rules.clear()
	buildings.clear()
	money = starting_money
	land_size = starting_land_size
	initial_storage_capacity = starting_capacity
	for resource_id: String in resource_ids:
		inventory[resource_id] = 0.0
		market_rules[resource_id] = {"enabled": bool(market_sell_defaults.get(resource_id, true)), "minimum_stock": 0.0}
	next_building_id = 1
	simulated_seconds = 0.0
	cumulative_revenue = 0.0
	cumulative_production = 0.0
	prestige_points = 0
	prestige_count = 0
	sound_enabled = true


func storage_used() -> float:
	var total: float = 0.0
	for amount: float in inventory.values():
		total += amount
	return total


func copy_state() -> GameState:
	var copied: GameState = GameState.new()
	copied.money = money
	copied.land_size = land_size
	copied.initial_storage_capacity = initial_storage_capacity
	copied.inventory = inventory.duplicate()
	copied.market_rules = market_rules.duplicate(true)
	copied.next_building_id = next_building_id
	copied.simulated_seconds = simulated_seconds
	copied.cumulative_revenue = cumulative_revenue
	copied.cumulative_production = cumulative_production
	copied.prestige_points = prestige_points
	copied.prestige_count = prestige_count
	copied.sound_enabled = sound_enabled
	for building: BuildingInstance in buildings:
		var copied_building: BuildingInstance = BuildingInstance.new()
		copied_building.id = building.id
		copied_building.definition_id = building.definition_id
		copied_building.cell = building.cell
		copied_building.level = building.level
		copied_building.status = building.status
		copied_building.last_inputs = building.last_inputs.duplicate()
		copied_building.last_outputs = building.last_outputs.duplicate()
		copied_building.energy_stored = building.energy_stored
		copied.buildings.append(copied_building)
	return copied
