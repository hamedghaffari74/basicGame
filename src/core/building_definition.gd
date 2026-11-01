class_name BuildingDefinition
extends RefCounted

var id: String = ""
var name_fa: String = ""
var category: String = ""
var kind: String = ""
var glyph: String = "?"
var color_hex: String = "#ffffff"
var build_cost: float = 0.0
var recipe_id: String = ""
var storage_capacity: float = 0.0
var market_rate_per_second: float = 0.0
var power_output_per_second: float = 0.0
var power_demand_per_second: float = 0.0
var fuel_resource_id: String = ""
var fuel_per_energy: float = 0.0
var battery_capacity: float = 0.0
var battery_charge_per_second: float = 0.0
var battery_discharge_per_second: float = 0.0
var max_level: int = 1
var refund_rate: float = 0.5
var upgrade_base_multiplier: float = 4.5
var upgrade_level_increment: float = 1.4
var rate_per_level_increment: float = 0.3
var description_fa: String = ""
var tier: int = 1
var neighbor_effects: Array[Dictionary] = []
