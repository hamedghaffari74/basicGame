class_name GameCatalog
extends RefCounted

const SUPPORTED_BUILDING_KINDS: Array[String] = ["producer", "storage", "market", "shop", "power", "battery", "park", "decoration"]

var resources: Dictionary[String, ResourceDefinition] = {}
var recipes: Dictionary[String, RecipeDefinition] = {}
var buildings: Dictionary[String, BuildingDefinition] = {}
var balance: BalanceDefinition = BalanceDefinition.new()
var errors: Array[String] = []


func load_from_files(resource_path: String, recipe_path: String, building_path: String, balance_path: String) -> bool:
	errors.clear()
	resources.clear()
	recipes.clear()
	buildings.clear()
	balance = BalanceDefinition.new()
	_load_resources(resource_path)
	_load_recipes(recipe_path)
	_load_buildings(building_path)
	_load_balance(balance_path)
	_validate_references()
	return errors.is_empty()


func resource_ids() -> Array[String]:
	var ids: Array[String] = []
	for resource_id: String in resources:
		ids.append(resource_id)
	ids.sort()
	return ids


func market_sell_defaults() -> Dictionary[String, bool]:
	var defaults: Dictionary[String, bool] = {}
	for resource_id: String in resources:
		defaults[resource_id] = resources[resource_id].market_enabled_by_default
	return defaults


func _parse_file(path: String, root_key: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: فایل پیدا نشد" % path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s: فایل خوانده نشد" % path)
		return null
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	if parse_error != Error.OK:
		errors.append("%s: JSON نامعتبر در خط %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return null
	var root: Variant = parser.data
	if typeof(root) != TYPE_DICTIONARY:
		errors.append("%s: ریشه باید شیء JSON باشد" % path)
		return null
	var row_value: Variant = (root as Dictionary).get(root_key, null)
	if root_key == "balance":
		return root
	if typeof(row_value) != TYPE_ARRAY:
		errors.append("%s: فیلد %s باید آرایه باشد" % [path, root_key])
		return null
	return row_value


func _load_resources(path: String) -> void:
	var rows: Variant = _parse_file(path, "resources")
	if typeof(rows) != TYPE_ARRAY:
		return
	for row_value: Variant in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			errors.append("%s: هر منبع باید شیء باشد" % path)
			continue
		var row: Dictionary = row_value
		if typeof(row.get("id", null)) != TYPE_STRING:
			errors.append("%s: resources[].id باید متن باشد" % path)
			continue
		var resource_id: String = str(row.get("id", ""))
		if resource_id.is_empty():
			errors.append("%s: resources[].id الزامی است" % path)
			continue
		if resources.has(resource_id):
			errors.append("%s: شناسهٔ تکراری resources[%s].id" % [path, resource_id])
			continue
		if not _has_fields(row, ["name_fa", "unit_price", "color"], path, "resources[%s]" % resource_id):
			continue
		if typeof(row["name_fa"]) != TYPE_STRING or typeof(row["color"]) != TYPE_STRING or not _is_finite_number(row["unit_price"]):
			errors.append("%s: resources[%s].name_fa/color باید متن و unit_price باید عدد محدود باشد" % [path, resource_id])
			continue
		if row.has("market_enabled_by_default") and typeof(row["market_enabled_by_default"]) != TYPE_BOOL:
			errors.append("%s: resources[%s].market_enabled_by_default باید بولی باشد" % [path, resource_id])
			continue
		var definition: ResourceDefinition = ResourceDefinition.new()
		definition.id = resource_id
		definition.name_fa = str(row["name_fa"])
		definition.unit_price = float(row["unit_price"])
		definition.color_hex = str(row["color"])
		definition.market_enabled_by_default = bool(row.get("market_enabled_by_default", true))
		if definition.name_fa.is_empty() or definition.unit_price <= 0.0 or not _is_hex_color(definition.color_hex):
			errors.append("%s: resources[%s] دارای نام، قیمت یا رنگ نامعتبر است" % [path, resource_id])
			continue
		resources[resource_id] = definition


func _load_recipes(path: String) -> void:
	var rows: Variant = _parse_file(path, "recipes")
	if typeof(rows) != TYPE_ARRAY:
		return
	for row_value: Variant in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			errors.append("%s: هر دستور تولید باید شیء باشد" % path)
			continue
		var row: Dictionary = row_value
		if typeof(row.get("id", null)) != TYPE_STRING:
			errors.append("%s: recipes[].id باید متن باشد" % path)
			continue
		var recipe_id: String = str(row.get("id", ""))
		if recipe_id.is_empty():
			errors.append("%s: recipes[].id الزامی است" % path)
			continue
		if recipes.has(recipe_id):
			errors.append("%s: شناسهٔ تکراری recipes[%s].id" % [path, recipe_id])
			continue
		if not _has_fields(row, ["name_fa", "inputs", "outputs", "output_per_second"], path, "recipes[%s]" % recipe_id):
			continue
		if typeof(row["inputs"]) != TYPE_DICTIONARY or typeof(row["outputs"]) != TYPE_DICTIONARY:
			errors.append("%s: recipes[%s].inputs و outputs باید شیء باشند" % [path, recipe_id])
			continue
		if typeof(row["name_fa"]) != TYPE_STRING or not _is_finite_number(row["output_per_second"]):
			errors.append("%s: recipes[%s].name_fa باید متن و output_per_second باید عدد محدود باشد" % [path, recipe_id])
			continue
		var definition: RecipeDefinition = RecipeDefinition.new()
		definition.id = recipe_id
		definition.name_fa = str(row["name_fa"])
		definition.inputs = _number_map(row["inputs"], path, "recipes[%s].inputs" % recipe_id)
		definition.outputs = _number_map(row["outputs"], path, "recipes[%s].outputs" % recipe_id)
		definition.output_per_second = float(row["output_per_second"])
		if definition.inputs.is_empty() and definition.outputs.is_empty():
			errors.append("%s: recipes[%s] ورودی و خروجی ندارد" % [path, recipe_id])
		if definition.outputs.is_empty() or definition.output_per_second <= 0.0:
			errors.append("%s: recipes[%s] خروجی یا نرخ معتبر ندارد" % [path, recipe_id])
		recipes[recipe_id] = definition


func _load_buildings(path: String) -> void:
	var rows: Variant = _parse_file(path, "buildings")
	if typeof(rows) != TYPE_ARRAY:
		return
	for row_value: Variant in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			errors.append("%s: هر ساختمان باید شیء باشد" % path)
			continue
		var row: Dictionary = row_value
		if typeof(row.get("id", null)) != TYPE_STRING:
			errors.append("%s: buildings[].id باید متن باشد" % path)
			continue
		var building_id: String = str(row.get("id", ""))
		if building_id.is_empty():
			errors.append("%s: buildings[].id الزامی است" % path)
			continue
		if buildings.has(building_id):
			errors.append("%s: شناسهٔ تکراری buildings[%s].id" % [path, building_id])
			continue
		if not _has_fields(row, ["name_fa", "category", "kind", "glyph", "color", "build_cost", "max_level", "refund_rate", "upgrade_base_multiplier", "upgrade_level_increment", "rate_per_level_increment", "description_fa"], path, "buildings[%s]" % building_id):
			continue
		var text_fields: Array[String] = ["name_fa", "category", "kind", "glyph", "color", "description_fa"]
		var bad_type: bool = false
		for field: String in text_fields:
			if typeof(row[field]) != TYPE_STRING:
				errors.append("%s: buildings[%s].%s باید متن باشد" % [path, building_id, field])
				bad_type = true
		var number_fields: Array[String] = ["build_cost", "refund_rate", "upgrade_base_multiplier", "upgrade_level_increment", "rate_per_level_increment"]
		for field: String in number_fields:
			if not _is_finite_number(row[field]):
				errors.append("%s: buildings[%s].%s باید عدد محدود باشد" % [path, building_id, field])
				bad_type = true
		if not _is_integer_number(row["max_level"]):
			errors.append("%s: buildings[%s].max_level باید عدد صحیح باشد" % [path, building_id])
			bad_type = true
		for optional_field: String in ["recipe_id"]:
			if row.has(optional_field) and typeof(row[optional_field]) != TYPE_STRING:
				errors.append("%s: buildings[%s].%s باید متن باشد" % [path, building_id, optional_field])
				bad_type = true
		for optional_field: String in ["unlock_cost", "storage_capacity", "market_rate_per_second", "power_output_per_second", "power_demand_per_second", "fuel_per_energy", "battery_capacity", "battery_charge_per_second", "battery_discharge_per_second"]:
			if row.has(optional_field) and not _is_finite_number(row[optional_field]):
				errors.append("%s: buildings[%s].%s باید عدد محدود باشد" % [path, building_id, optional_field])
				bad_type = true
		if row.has("fuel_resource_id") and typeof(row["fuel_resource_id"]) != TYPE_STRING:
			errors.append("%s: buildings[%s].fuel_resource_id باید متن باشد" % [path, building_id])
			bad_type = true
		if row.has("tier") and (not _is_integer_number(row["tier"]) or int(row["tier"]) < 1 or int(row["tier"]) > 3):
			errors.append("%s: buildings[%s].tier باید بین ۱ و ۳ باشد" % [path, building_id])
			bad_type = true
		if row.has("neighbor_effects") and typeof(row["neighbor_effects"]) != TYPE_ARRAY:
			errors.append("%s: buildings[%s].neighbor_effects باید آرایه باشد" % [path, building_id])
			bad_type = true
		if bad_type:
			continue
		var definition: BuildingDefinition = BuildingDefinition.new()
		definition.id = building_id
		definition.name_fa = str(row["name_fa"])
		definition.category = str(row["category"])
		definition.kind = str(row["kind"])
		definition.glyph = str(row["glyph"])
		definition.color_hex = str(row["color"])
		definition.build_cost = _number(row["build_cost"])
		definition.unlock_cost = _number(row.get("unlock_cost", 0.0))
		definition.max_level = int(row["max_level"])
		definition.refund_rate = _number(row["refund_rate"])
		definition.upgrade_base_multiplier = _number(row["upgrade_base_multiplier"])
		definition.upgrade_level_increment = _number(row["upgrade_level_increment"])
		definition.rate_per_level_increment = _number(row["rate_per_level_increment"])
		definition.description_fa = str(row["description_fa"])
		definition.tier = int(row.get("tier", 1))
		var effect_rows: Variant = row.get("neighbor_effects", [])
		if typeof(effect_rows) == TYPE_ARRAY:
			for effect_value: Variant in effect_rows:
				if typeof(effect_value) != TYPE_DICTIONARY:
					errors.append("%s: buildings[%s].neighbor_effects هر مورد باید شیء باشد" % [path, building_id])
					continue
				var effect: Dictionary = effect_value
				var target_kind: Variant = effect.get("target_kind", "")
				var target_category: Variant = effect.get("target_category", "")
				var bonus: Variant = effect.get("bonus", null)
				if typeof(target_kind) != TYPE_STRING or typeof(target_category) != TYPE_STRING or not _is_finite_number(bonus) or float(bonus) <= 0.0 or (str(target_kind).is_empty() and str(target_category).is_empty()):
					errors.append("%s: buildings[%s].neighbor_effects هدف یا bonus نامعتبر دارد" % [path, building_id])
					continue
				definition.neighbor_effects.append({"target_kind": str(target_kind), "target_category": str(target_category), "bonus": float(bonus)})
		definition.recipe_id = str(row.get("recipe_id", ""))
		definition.storage_capacity = _number(row.get("storage_capacity", 0.0))
		definition.market_rate_per_second = _number(row.get("market_rate_per_second", 0.0))
		definition.power_output_per_second = _number(row.get("power_output_per_second", 0.0))
		definition.power_demand_per_second = _number(row.get("power_demand_per_second", 0.0))
		definition.fuel_resource_id = str(row.get("fuel_resource_id", ""))
		definition.fuel_per_energy = _number(row.get("fuel_per_energy", 0.0))
		definition.battery_capacity = _number(row.get("battery_capacity", 0.0))
		definition.battery_charge_per_second = _number(row.get("battery_charge_per_second", 0.0))
		definition.battery_discharge_per_second = _number(row.get("battery_discharge_per_second", 0.0))
		if not _is_hex_color(definition.color_hex):
			errors.append("%s: buildings[%s].color قالب رنگ معتبر ندارد" % [path, building_id])
		if not SUPPORTED_BUILDING_KINDS.has(definition.kind):
			errors.append("%s: buildings[%s].kind پشتیبانی نمی‌شود: %s" % [path, building_id, definition.kind])
		if definition.build_cost <= 0.0 or definition.max_level < 1 or definition.max_level > 10:
			errors.append("%s: buildings[%s] هزینه یا سطح نامعتبر دارد" % [path, building_id])
		if definition.unlock_cost < 0.0 or (definition.tier == 1 and definition.unlock_cost > 0.0):
			errors.append("%s: buildings[%s].unlock_cost باید نامنفی باشد و ساختمان‌های Tier 1 رایگان بمانند" % [path, building_id])
		if definition.refund_rate < 0.0 or definition.refund_rate > 1.0:
			errors.append("%s: buildings[%s].refund_rate باید بین ۰ و ۱ باشد" % [path, building_id])
		if definition.upgrade_base_multiplier < 0.0 or definition.upgrade_level_increment < 0.0 or definition.rate_per_level_increment < 0.0:
			errors.append("%s: buildings[%s] ضریب ارتقای منفی دارد" % [path, building_id])
		if definition.kind == "producer" and definition.recipe_id.is_empty():
			errors.append("%s: buildings[%s].recipe_id برای تولیدکننده الزامی است" % [path, building_id])
		if definition.kind == "storage" and definition.storage_capacity <= 0.0:
			errors.append("%s: buildings[%s].storage_capacity باید مثبت باشد" % [path, building_id])
		if definition.kind == "market" and definition.market_rate_per_second <= 0.0:
			errors.append("%s: buildings[%s].market_rate_per_second باید مثبت باشد" % [path, building_id])
		if definition.power_demand_per_second < 0.0:
			errors.append("%s: buildings[%s].power_demand_per_second نمی‌تواند منفی باشد" % [path, building_id])
		for power_field: String in ["power_output_per_second", "fuel_per_energy", "battery_capacity", "battery_charge_per_second", "battery_discharge_per_second"]:
			if _number(row.get(power_field, 0.0)) < 0.0:
				errors.append("%s: buildings[%s].%s نمی‌تواند منفی باشد" % [path, building_id, power_field])
		if definition.kind == "power" and definition.power_output_per_second <= 0.0:
			errors.append("%s: buildings[%s].power_output_per_second باید مثبت باشد" % [path, building_id])
		if not definition.fuel_resource_id.is_empty():
			if not resources.has(definition.fuel_resource_id) or definition.fuel_per_energy <= 0.0:
				errors.append("%s: buildings[%s] منبع یا نرخ سوخت نامعتبر دارد" % [path, building_id])
		elif definition.fuel_per_energy != 0.0:
			errors.append("%s: buildings[%s].fuel_per_energy بدون fuel_resource_id معتبر نیست" % [path, building_id])
		if definition.kind == "battery" and (definition.battery_capacity <= 0.0 or definition.battery_charge_per_second <= 0.0 or definition.battery_discharge_per_second <= 0.0):
			errors.append("%s: buildings[%s] ظرفیت و نرخ شارژ/تخلیهٔ باتری باید مثبت باشند" % [path, building_id])
		buildings[building_id] = definition


func _load_balance(path: String) -> void:
	var root: Variant = _parse_file(path, "balance")
	if typeof(root) != TYPE_DICTIONARY:
		return
	var row: Dictionary = root
	var required: Array[String] = ["initial_money", "initial_land_size", "maximum_land_size", "initial_storage_capacity", "tick_seconds", "max_steps_per_frame", "max_backlog_seconds", "autosave_seconds", "production_tolerance"]
	if not _has_fields(row, required, path, "balance"):
		return
	var numeric_fields: Array[String] = ["initial_money", "initial_storage_capacity", "tick_seconds", "max_backlog_seconds", "autosave_seconds", "production_tolerance"]
	for field: String in numeric_fields:
		if not _is_finite_number(row[field]) or float(row[field]) <= 0.0:
			errors.append("%s: balance.%s باید عدد مثبت باشد" % [path, field])
	var integer_fields: Array[String] = ["initial_land_size", "maximum_land_size", "max_steps_per_frame"]
	for field: String in integer_fields:
		if not _is_integer_number(row[field]) or int(row[field]) <= 0:
			errors.append("%s: balance.%s باید عدد صحیح مثبت باشد" % [path, field])
	if not errors.is_empty():
		return
	balance.initial_money = float(row["initial_money"])
	balance.initial_land_size = int(row["initial_land_size"])
	balance.maximum_land_size = int(row["maximum_land_size"])
	balance.initial_storage_capacity = float(row["initial_storage_capacity"])
	balance.tick_seconds = float(row["tick_seconds"])
	balance.max_steps_per_frame = int(row["max_steps_per_frame"])
	balance.max_backlog_seconds = float(row["max_backlog_seconds"])
	balance.autosave_seconds = float(row["autosave_seconds"])
	balance.production_tolerance = float(row["production_tolerance"])
	balance.tier_two_revenue = _number(row.get("tier_two_revenue", 450.0))
	balance.tier_three_revenue = _number(row.get("tier_three_revenue", 2500.0))
	balance.tier_two_production = _number(row.get("tier_two_production", 150.0))
	balance.tier_three_production = _number(row.get("tier_three_production", 900.0))
	balance.neighbor_bonus_cap = _number(row.get("neighbor_bonus_cap", 0.4))
	balance.offline_cap_seconds = int(row.get("offline_cap_seconds", 28800))
	balance.prestige_base_revenue = _number(row.get("prestige_base_revenue", 10000.0))
	balance.prestige_bonus_per_point = _number(row.get("prestige_bonus_per_point", 0.05))
	balance.prestige_bonus_cap = _number(row.get("prestige_bonus_cap", 0.5))
	balance.expansion_steps.clear()
	var expansion_rows: Variant = row.get("expansion_steps", [])
	if typeof(expansion_rows) == TYPE_ARRAY:
		for step_value: Variant in expansion_rows:
			if typeof(step_value) != TYPE_DICTIONARY:
				errors.append("%s: balance.expansion_steps باید از اشیاء تشکیل شود" % path)
				continue
			var step: Dictionary = step_value
			if not _is_integer_number(step.get("size", null)) or not _is_finite_number(step.get("cost", null)) or float(step.get("cost", -1.0)) < 0.0 or not _is_finite_number(step.get("revenue", null)) or float(step.get("revenue", -1.0)) < 0.0:
				errors.append("%s: یکی از گام‌های گسترش زمین نامعتبر است" % path)
				continue
			balance.expansion_steps.append({"size": int(step["size"]), "cost": float(step["cost"]), "revenue": float(step["revenue"])})
	if balance.tier_two_revenue <= 0.0 or balance.tier_three_revenue <= balance.tier_two_revenue or balance.tier_two_production <= 0.0 or balance.tier_three_production <= balance.tier_two_production or balance.neighbor_bonus_cap < 0.0 or balance.offline_cap_seconds < 0 or balance.prestige_base_revenue <= 0.0 or balance.prestige_bonus_per_point < 0.0 or balance.prestige_bonus_cap < 0.0:
		errors.append("%s: قواعد tier، همسایگی، آفلاین یا پرستیژ نامعتبر هستند" % path)
	var previous_size: int = balance.initial_land_size
	for step: Dictionary in balance.expansion_steps:
		if int(step["size"]) <= previous_size or int(step["size"]) > balance.maximum_land_size:
			errors.append("%s: اندازهٔ مراحل گسترش باید افزایشی و در محدودهٔ زمین باشد" % path)
		previous_size = int(step["size"])
	if balance.initial_land_size > balance.maximum_land_size:
		errors.append("%s: balance.initial_land_size از maximum_land_size بزرگ‌تر است" % path)


func _validate_references() -> void:
	for recipe: RecipeDefinition in recipes.values():
		for resource_id: String in recipe.inputs:
			if not resources.has(resource_id):
				errors.append("data/recipes.json: recipes[%s].inputs به منبع نامعتبر اشاره می‌کند: %s" % [recipe.id, resource_id])
			if not _positive_number(recipe.inputs[resource_id]):
				errors.append("data/recipes.json: recipes[%s].inputs[%s] باید مثبت باشد" % [recipe.id, resource_id])
		for resource_id: String in recipe.outputs:
			if not resources.has(resource_id):
				errors.append("data/recipes.json: recipes[%s].outputs به منبع نامعتبر اشاره می‌کند: %s" % [recipe.id, resource_id])
			if not _positive_number(recipe.outputs[resource_id]):
				errors.append("data/recipes.json: recipes[%s].outputs[%s] باید مثبت باشد" % [recipe.id, resource_id])
	var supplied_resources: Dictionary[String, bool] = {}
	for building: BuildingDefinition in buildings.values():
		if building.kind == "producer" and not recipes.has(building.recipe_id):
			errors.append("data/buildings.json: buildings[%s].recipe_id نامعتبر است: %s" % [building.id, building.recipe_id])
		elif building.kind == "producer":
			for resource_id: String in recipes[building.recipe_id].outputs:
				supplied_resources[resource_id] = true
	for recipe: RecipeDefinition in recipes.values():
		for resource_id: String in recipe.inputs:
			if not supplied_resources.has(resource_id):
				errors.append("data/recipes.json: recipes[%s].inputs[%s] ساختمان تأمین‌کننده ندارد" % [recipe.id, resource_id])
	_validate_recipe_cycles()


func _validate_recipe_cycles() -> void:
	var dependencies: Dictionary[String, Array] = {}
	for recipe: RecipeDefinition in recipes.values():
		for output_id: String in recipe.outputs:
			if not dependencies.has(output_id):
				dependencies[output_id] = []
			for input_id: String in recipe.inputs:
				if not dependencies[output_id].has(input_id):
					dependencies[output_id].append(input_id)
	var visited: Dictionary[String, bool] = {}
	var active: Dictionary[String, bool] = {}
	for resource_id: String in resources:
		if _has_dependency_cycle(resource_id, dependencies, visited, active):
			errors.append("data/recipes.json: زنجیرهٔ Recipe برای %s چرخه دارد" % resource_id)
			return


func _has_dependency_cycle(resource_id: String, dependencies: Dictionary[String, Array], visited: Dictionary[String, bool], active: Dictionary[String, bool]) -> bool:
	if active.has(resource_id):
		return true
	if visited.has(resource_id):
		return false
	visited[resource_id] = true
	active[resource_id] = true
	for dependency_id: String in dependencies.get(resource_id, []):
		if _has_dependency_cycle(dependency_id, dependencies, visited, active):
			return true
	active.erase(resource_id)
	return false


func _number_map(value: Dictionary, path: String, field: String) -> Dictionary[String, float]:
	var result: Dictionary[String, float] = {}
	for key_value: Variant in value.keys():
		var resource_id: String = str(key_value)
		var amount: Variant = value[key_value]
		if typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT:
			errors.append("%s: %s[%s] باید عدد باشد" % [path, field, resource_id])
			continue
		result[resource_id] = float(amount)
	return result


func _has_fields(row: Dictionary, fields: Array[String], path: String, context: String) -> bool:
	var complete: bool = true
	for field: String in fields:
		if not row.has(field):
			errors.append("%s: %s.%s الزامی است" % [path, context, field])
			complete = false
	return complete


func _positive_number(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) > 0.0


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _is_integer_number(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) == float(int(value))


func _is_hex_color(value: String) -> bool:
	if value.length() != 7 and value.length() != 9:
		return false
	if not value.begins_with("#"):
		return false
	const HEX_DIGITS: String = "0123456789abcdefABCDEF"
	for index: int in range(1, value.length()):
		if HEX_DIGITS.find(value.substr(index, 1)) < 0:
			return false
	return true


func _number(value: Variant) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return 0.0
