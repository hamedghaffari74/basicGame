class_name GameCommand
extends RefCounted

enum Kind { BUILD, DEMOLISH, UPGRADE, SET_MARKET_RULE, SELL_RESOURCE, EXPAND_LAND, PRESTIGE }

var kind: Kind = Kind.BUILD
var definition_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var building_id: int = 0
var resource_id: String = ""
var sell_enabled: bool = true
var minimum_stock: float = 0.0


static func build(build_id: String, target_cell: Vector2i) -> GameCommand:
	var command: GameCommand = GameCommand.new()
	command.kind = Kind.BUILD
	command.definition_id = build_id
	command.cell = target_cell
	return command


static func demolish(target_building_id: int) -> GameCommand:
	var command: GameCommand = GameCommand.new()
	command.kind = Kind.DEMOLISH
	command.building_id = target_building_id
	return command


static func upgrade(target_building_id: int) -> GameCommand:
	var command: GameCommand = GameCommand.new()
	command.kind = Kind.UPGRADE
	command.building_id = target_building_id
	return command


static func set_market_rule(target_resource_id: String, enabled: bool, minimum: float) -> GameCommand:
	var command: GameCommand = GameCommand.new()
	command.kind = Kind.SET_MARKET_RULE
	command.resource_id = target_resource_id
	command.sell_enabled = enabled
	command.minimum_stock = minimum
	return command


static func sell_resource(target_resource_id: String) -> GameCommand:
	var command: GameCommand = GameCommand.new()
	command.kind = Kind.SELL_RESOURCE
	command.resource_id = target_resource_id
	return command


static func expand_land() -> GameCommand:
	var command: GameCommand = GameCommand.new()
	command.kind = Kind.EXPAND_LAND
	return command


static func prestige() -> GameCommand:
	var command: GameCommand = GameCommand.new()
	command.kind = Kind.PRESTIGE
	return command
