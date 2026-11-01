class_name BalanceDefinition
extends RefCounted

var initial_money: float = 0.0
var initial_land_size: int = 8
var maximum_land_size: int = 24
var initial_storage_capacity: float = 40.0
var tick_seconds: float = 0.1
var max_steps_per_frame: int = 20
var max_backlog_seconds: float = 2.0
var autosave_seconds: float = 30.0
var production_tolerance: float = 0.000001
var tier_two_revenue: float = 450.0
var tier_three_revenue: float = 2500.0
var tier_two_production: float = 150.0
var tier_three_production: float = 900.0
var neighbor_bonus_cap: float = 0.4
var offline_cap_seconds: int = 28800
var prestige_base_revenue: float = 10000.0
var prestige_bonus_per_point: float = 0.05
var prestige_bonus_cap: float = 0.5
var expansion_steps: Array[Dictionary] = []
