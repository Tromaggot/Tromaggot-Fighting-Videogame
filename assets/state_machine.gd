class_name StateMachine
extends Node
signal state_changed(old_state: String, new_state: String)
var current_state: String = ""
var states: Dictionary = {}
func _ready() -> void:
	pass
func add_state(state_name: String) -> void:
	states[state_name] = true
func change_state(new_state: String) -> void:
	if new_state == current_state:
		return
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
func is_state(state_name: String) -> bool:
	return current_state == state_name
