extends Node

class_name MultiplayerHandler

@export var scene_spawn_player: PackedScene
@onready var actors_parent := $Actors
@export var screen: Screen

var local_player: PlayerController

signal player_joined(player: PlayerController, id: int)

@export var game_world_manager: GameWorldManager

func _on_world_changed(new_world: GameWorld):
    assert(new_world)
    for actor in actors_parent.get_children():
        if actor is PlayerController:
            new_world.add_player(actor)
            print("Set player in world ", actor)
                
func _deferred_create_player(id: int) -> void:
    var new_player: PlayerController = scene_spawn_player.instantiate()
    assert(new_player)
    new_player.name = str(id)
    actors_parent.add_child(new_player)
    game_world_manager.add_player(new_player)
    
    if id == 1:
        assert(!local_player)
        local_player = new_player
        
    player_joined.emit(new_player, id)

func _create_player(id: int) -> void:
    _deferred_create_player.call_deferred(id)

func _new_peer_server(port: int, use_websocket: bool) -> MultiplayerPeer:
    var peer: MultiplayerPeer
    if use_websocket:
        peer = WebSocketMultiplayerPeer.new()
    else:
        peer = ENetMultiplayerPeer.new()
        
    var err = peer.create_server(port)
    
    if err != OK:
        push_error("create_server(%d) failed: %s" % [port, error_string(err)])
        return null
        
    return peer

func _new_peer_client(host: String, port: int, use_websocket: bool) -> MultiplayerPeer:
    var peer: MultiplayerPeer
    if use_websocket:
        peer = WebSocketMultiplayerPeer.new()
        var err = peer.create_client("ws://%s:%d" % [host, port]) 
        if err != OK:
            push_error("create_client(%s:%d) failed: %s" % [host, port, error_string(err)])
            return null
    else:
        peer = ENetMultiplayerPeer.new()
        var err = peer.create_client(host, port)
        if err != OK:
            push_error("create_client(%s:%d) failed: %s" % [host, port, error_string(err)])
            return null
            
    return peer

func singleplayer_start() -> void:
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    NetworkTime.start()
    _deferred_create_player.call_deferred(1)

func server_start(port: int) -> void:
    multiplayer.multiplayer_peer = _new_peer_server(port, true)
    _deferred_create_player.call_deferred(1)

func client_connect(host: String, port: int) -> void:
    print("Connecting to ", host, " port ", port)
    multiplayer.multiplayer_peer = _new_peer_client(host, port, true)

func client_disconnect():
    multiplayer.multiplayer_peer.close()
    #game_stopped.emit()

func _on_peer_connected(id: int) -> void:
    _create_player(id)
    
func _ready():
    game_world_manager.world_changed.connect(_on_world_changed)
    multiplayer.peer_connected.connect(_on_peer_connected)
