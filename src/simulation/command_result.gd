class_name CommandResult
extends RefCounted

var succeeded: bool = false
var code: String = ""
var message: String = ""
var subject_id: int = 0


func _init(was_successful: bool = false, result_code: String = "", result_message: String = "", target_id: int = 0) -> void:
	succeeded = was_successful
	code = result_code
	message = result_message
	subject_id = target_id
