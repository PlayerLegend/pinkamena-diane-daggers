extends Node

@export var multiplayer_handler: MultiplayerHandler

func _on_save_config() -> void:
    Config.save()

func _helper_start_server(port: int):
    multiplayer_handler.server_start(port)

func _helper_connect_server(host: String, port: int):
    multiplayer_handler.client_connect(host, port)

func _on_netsim_server_created():
    _helper_start_server.call_deferred(NetworkSimulator.server_port)
    
func _on_netsim_client_connected():
    _helper_connect_server.call_deferred(NetworkSimulator.hostname, NetworkSimulator.server_port)

func _ready():
    NetworkSimulator.server_created.connect(_on_netsim_server_created)
    NetworkSimulator.client_connected.connect(_on_netsim_client_connected)
