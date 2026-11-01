class_name BuildingInstance
extends RefCounted

var id: int = 0
var definition_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var level: int = 1
var status: String = "idle"
var last_inputs: Dictionary[String, float] = {}
var last_outputs: Dictionary[String, float] = {}
var energy_stored: float = 0.0
