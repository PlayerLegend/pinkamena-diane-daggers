extends Node

@export var multiplayer_handler: MultiplayerHandler
@onready var main_menu: MainMenu = $MainMenu
@export var guide_map_fps: GUIDEMappingContext
@onready var escape_menu: EscapeMenu = $EscapeMenu
@export var start_world_scene: PackedScene
@export var menu_world_scene: PackedScene
@export var main_world_scene: PackedScene
@onready var game_world_manager: GameWorldManager = $GameWorldManager
@export var game_start_audio: AudioStream
@export var game_over_audio: AudioStream
@onready var non_spatial_audio: MultiVoicePlayer = $NonSpatialAudio
@export var game_over_screen: GameOverScreen

var current_menu: Control

@export var boid_types: Array[BoidType]
@onready var screen: Screen = $Screen

var server_is_started: bool

var hide_frames: int = 0

func _on_save_config() -> void:
    Config.save()

func _set_world(next: PackedScene):
    if next:
        game_world_manager.game_world = next.instantiate()
    else:
        game_world_manager.game_world = null

func _start_game():
    _set_world(start_world_scene)
    if not server_is_started:
        multiplayer_handler.singleplayer_start()
    server_is_started = true
    _show_game()

func _start_server(port: int):
    _set_world(start_world_scene)
    if not server_is_started:
        multiplayer_handler.server_start(port)
    server_is_started = true
    _show_game()

func _connect_server(host: String, port: int):
    multiplayer_handler.client_connect(host, port)

func _show_game():
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    GUIDE.enable_mapping_context(guide_map_fps)
    if current_menu:
        current_menu.visible = false
        current_menu = null

func _process(_delta: float):
    if hide_frames <= 0:
        if not screen.visible:
            screen.visible = true
    else:
        hide_frames -= 1
    if game_world_manager.game_world is MenuWorld and not main_menu.visible:
        main_menu.show()
        GUIDE.disable_mapping_context(guide_map_fps)
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        
func _show_menu(next: Control):
    GUIDE.disable_mapping_context(guide_map_fps)
    Input.set_mouse_mode.call_deferred(Input.MOUSE_MODE_VISIBLE)
    assert(next)
    if current_menu == next:
        if next.visible:
            return
    
    if current_menu:
        current_menu.visible = false
    current_menu = next
    current_menu.visible = true
    if current_menu is MainMenu:
        print("SET MAIN MENU")
        _set_world(menu_world_scene)
        
    #if not main_menu.visible:
        #main_menu.visible = true
    #if not game_world_manager.game_world is MenuWorld:
        #set_world(menu_world_scene)
    
func _on_netsim_server_created():
    _start_server.call_deferred(NetworkSimulator.server_port)
    _show_game()
    
func _on_netsim_client_connected():
    _connect_server.call_deferred(NetworkSimulator.hostname, NetworkSimulator.server_port)
    _show_game()


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if not current_menu is MainMenu:
            _show_menu(main_menu)

func _on_player_joined(player: PlayerController, id: int):
    if id == 1:
        screen.player_controller = player

func _on_player_died(player: PlayerController, stats: GameOverStats):
    _show_menu(game_over_screen)
    game_over_screen.set_stats(stats)
    player.visible = false
    non_spatial_audio.play_sound(game_over_audio)

func _restart_game():
    _set_world(main_world_scene)
    _show_game()

func _ready():
    assert(main_menu)
    assert(multiplayer_handler)
    assert(start_world_scene)
    assert(menu_world_scene)
    assert(game_start_audio)
    assert(game_over_screen)
    assert(boid_types)
    assert(main_world_scene)
    
    NetworkSimulator.server_created.connect(_on_netsim_server_created)
    NetworkSimulator.client_connected.connect(_on_netsim_client_connected)
    multiplayer_handler.player_joined.connect(_on_player_joined)
    game_over_screen.did_press_retry.connect(_restart_game)
    _show_menu(main_menu)

func _on_main_menu_net_host(port: int) -> void:
    _start_server.call_deferred(port)

func _on_game_world_manager_world_changed(new_world: GameWorld) -> void:
    screen.visible = false
    hide_frames = 5
    non_spatial_audio.play_sound(game_start_audio)
    if new_world is MainGameWorld:
        new_world.player_died.connect(_on_player_died)
        print("Connected player died signal")

func _on_main_menu_singleplayer_start() -> void:
    _start_game()
