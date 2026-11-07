extends VBoxContainer

signal net_host(port: int)
signal net_connect(host: String, port: int)
signal net_disconnect()
signal set_mouse_scale(scale: float, area: float, degrees: float)
signal save_config()

func _on_network_net_connect(host: String, port: int) -> void:
    net_connect.emit(host, port)
    hide()

func _on_network_net_disconnect() -> void:
    net_disconnect.emit()

func _on_network_net_host(port: int) -> void:
    net_host.emit(port)
    hide()

func _on_mouse_config_set_mouse_scale(mscale: float, area: float, degrees: float) -> void:
    set_mouse_scale.emit(mscale, area, degrees)
    hide()

func _on_save_config_save_config() -> void:
    save_config.emit()
