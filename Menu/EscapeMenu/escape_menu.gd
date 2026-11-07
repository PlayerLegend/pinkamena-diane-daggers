extends ColorRect

signal set_mouse_scale(scale: float, area: float, degrees: float)
signal save_config()

func _on_mouse_config_set_mouse_scale(mscale: float, area: float, degrees: float) -> void:
    set_mouse_scale.emit(mscale, area, degrees)

func _on_save_config_save_config() -> void:
    save_config.emit()
