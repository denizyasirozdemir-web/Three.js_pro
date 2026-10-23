@tool
extends StaticBody3D
## Generic interactable object. World code supplies callbacks for prompt and use.

var prompt_cb: Callable
var use_cb: Callable
var enabled := true


func get_prompt() -> String:
	if not enabled or not prompt_cb.is_valid():
		return ""
	return prompt_cb.call()


func interact(_player) -> void:
	if enabled and use_cb.is_valid():
		use_cb.call()
