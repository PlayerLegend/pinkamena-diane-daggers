extends VBoxContainer

signal net_host(port: int)
signal net_connect(host: String, port: int)
signal net_disconnect()

@export var default_port: int = 38214

@onready var _ui_connected_options := $ConnectedOptions
@onready var _ui_host := $ConnectedOptions/Address
@onready var _ui_port := $ConnectedOptions/Port

@onready var _ui_disconnected_options := $DisconnectedOptions
@onready var _ui_server_display := $DisconnectedOptions/Server

func _helper_get_host_for_client() -> String:
    var result = _ui_host.text
    print("Got host text ", _ui_host.text)
    if result:
        return result
    else:
        return "127.0.0.1"
        
func _helper_get_port() -> int:
    var result = _ui_port.text
    if result:
        return result.to_int()
    else:
        return default_port
        
func _on_disconnect() -> void:
    _ui_connected_options.hide()
    _ui_disconnected_options.show()
    
func _on_connect(host: String, port: int):
    _ui_connected_options.show()
    _ui_disconnected_options.hide()
    _ui_server_display.text = host + ": " + str(port)
    
func _on_host_button_down() -> void:
    net_host.emit(_helper_get_port())

func _on_connect_button_down() -> void:
    net_connect.emit(
        _helper_get_host_for_client(),
        _helper_get_port()
    )

func _on_disconnect_button_button_down() -> void:
    net_disconnect.emit()
