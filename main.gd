extends Node

@export var multiplayer_handler: MultiplayerHandler
@onready var main_menu: MainMenu = $MainMenu
@export var guide_map_fps: GUIDEMappingContext
@onready var escape_menu: EscapeMenu = $EscapeMenu
@export var start_world_scene: PackedScene
@export var menu_world_scene: PackedScene
@onready var game_world_manager: GameWorldManager = $GameWorldManager
@export var game_start_audio: AudioStream
@onready var non_spatial_audio: SoundPlayer = $NonSpatialAudio

@export var boid_types: Array[BoidType]
@onready var screen: Screen = $Screen

var server_is_started: bool

func _on_save_config() -> void:
    Config.save()

func set_world(next: PackedScene):
    if next:
        game_world_manager.game_world = next.instantiate()
    else:
        game_world_manager.game_world = null

func _helper_start_server(port: int):
    set_world(start_world_scene)
    if not server_is_started:
        multiplayer_handler.server_start(port)
    server_is_started = true
    _helper_show_game()

func _helper_connect_server(host: String, port: int):
    multiplayer_handler.client_connect(host, port)

func _helper_show_game():
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    GUIDE.enable_mapping_context(guide_map_fps)
    main_menu.hide()
    escape_menu.hide()

func _process(_delta: float):
    if game_world_manager.game_world is MenuWorld and not main_menu.visible:
        main_menu.show()
        GUIDE.disable_mapping_context(guide_map_fps)
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        

func _helper_show_menu():
    GUIDE.disable_mapping_context(guide_map_fps)
    Input.set_mouse_mode.call_deferred(Input.MOUSE_MODE_VISIBLE)
    if not main_menu.visible:
        main_menu.visible = true
    if not game_world_manager.game_world is MenuWorld:
        set_world(menu_world_scene)
    
func _on_netsim_server_created():
    _helper_start_server.call_deferred(NetworkSimulator.server_port)
    _helper_show_game()
    
func _on_netsim_client_connected():
    _helper_connect_server.call_deferred(NetworkSimulator.hostname, NetworkSimulator.server_port)
    _helper_show_game()

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if GUIDE.is_mapping_context_enabled(guide_map_fps):
            _helper_show_menu()
        else:
            _helper_show_game()

func _on_player_joined(player: PlayerController, id: int):
    if id == 1:
        screen.player_controller = player

func _ready():
    NetworkSimulator.server_created.connect(_on_netsim_server_created)
    NetworkSimulator.client_connected.connect(_on_netsim_client_connected)
    set_world(menu_world_scene)
    multiplayer_handler.player_joined.connect(_on_player_joined)

func _on_main_menu_net_host(port: int) -> void:
    _helper_start_server.call_deferred(port)

func _on_game_world_manager_world_changed(_new_world: GameWorld) -> void:
    non_spatial_audio.play_sound(game_start_audio)
