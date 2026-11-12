extends Node

class_name MultiplayerHandler

@export var scene_spawn_player: PackedScene
@onready var actors_parent := $Actors
@export var screen: Screen

#signal game_started()
#signal game_stopped()
signal create_player(id: int)
signal net_is_connected(host: String, port: int)

func _helper_find_spawn() -> Node3D:
    return get_tree().get_nodes_in_group("player_spawns").pick_random()

func _deferred_create_player(id: int) -> void:
    var new_player: PlayerController = scene_spawn_player.instantiate()
    assert(new_player)
    new_player.name = str(id)
    actors_parent.add_child(new_player)
    
    var target_spawn = _helper_find_spawn()
    assert(target_spawn)
    new_player.transform = target_spawn.transform
    if id == 1:
        screen.player_controller = new_player

func _on_create_player(id: int) -> void:
    _deferred_create_player.call_deferred(id)

func server_start(port: int) -> void:
    var peer = ENetMultiplayerPeer.new()
    peer.create_server(port)
    multiplayer.multiplayer_peer = peer
    _deferred_create_player.call_deferred(1)
    #game_started.emit()
    net_is_connected.emit("127.0.0.1", port)

func client_connect(host: String, port: int) -> void:
    print("Connecting to ", host, " port ", port)
    var peer = ENetMultiplayerPeer.new()
    peer.create_client(host,port)
    multiplayer.multiplayer_peer = peer
    #game_started.emit()
    net_is_connected.emit(host, port)

func client_disconnect():
    multiplayer.multiplayer_peer.close()
    #game_stopped.emit()

func set_mouse_scale(mouse_scale: float):
    for child in actors_parent.get_children():
        if child.has_method("set_mouse_scale"):
            child.set_mouse_scale(mouse_scale)

func _on_peer_connected(id: int) -> void:
    create_player.emit(id)
    
func _ready():
    multiplayer.peer_connected.connect(_on_peer_connected)
    create_player.connect(_on_create_player)
