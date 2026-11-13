class_name MainMenu
extends Control

signal net_host(port: int)
signal net_connect(host: String, port: int)
signal net_disconnect()
signal set_mouse_scale(scale: float, area: float, degrees: float)
signal save_config()
@onready var camera_3d: Camera3D = $Background/Camera3D
@onready var background: Node3D = $Background

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


func _on_play_button_pressed() -> void:
    net_host.emit(32357)


func _on_exit_button_pressed() -> void:
    get_tree().quit()

func get_camera_global_transform() -> Transform3D:
    return camera_3d.global_transform

func _on_visibility_changed() -> void:
    background.visible = visible

func _ready() -> void:
    visibility_changed.connect(_on_visibility_changed)
