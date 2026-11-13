extends ColorRect

class_name Screen

@onready var subviewport: SubViewport = $SubViewport
@onready var camera_3d: Camera3D = $SubViewport/Camera3D
@export var time_display: Label
@export var score_display: Label

@export var render_height: int = 0
@export var enable_fps_counter: bool = false
@export var player_controller: PlayerController:
    set(value):
        if value is PlayerController:
            value.attack_power_changed.connect(_on_player_attack_power_changed)
            player_controller = value
@export var main_menu: MainMenu
@export var game_world_manager: GameWorldManager

func _on_player_attack_power_changed(_player: PlayerController):
    pass

func _process(_delta: float) -> void:
    if not camera_3d:
        return

    var output_resolution: Vector2 = size  # or get_global_rect().size
    if output_resolution.x < 1.0 or output_resolution.y < 1.0:
        return  # layout not ready yet

    var heightf: float = output_resolution.y
    if render_height > 0:
        heightf = float(render_height)
    var render_resolution := Vector2i(
        maxi(1, roundi(output_resolution.x * heightf / output_resolution.y)),
        maxi(1, roundi(heightf))
    )

    if subviewport.size != render_resolution:
        subviewport.size = render_resolution

    camera_3d.make_current()
    
    if score_display.visible:
        if player_controller:
            score_display.text = str(player_controller.attack_power)
            
    if time_display.visible:
        if game_world_manager.game_world:
            time_display.text = String.num(game_world_manager.game_world.time, 1)
    
    if not player_controller or game_world_manager.game_world is MenuWorld:
        camera_3d.global_transform = main_menu.get_camera_global_transform()
    else:
        camera_3d.global_transform = player_controller.get_camera_global_transform()
    
func _ready():
    get_viewport().disable_3d = true
    process_priority = 100
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mat := material as ShaderMaterial
    if mat:
        mat = mat.duplicate() as ShaderMaterial
        material = mat
        mat.set_shader_parameter("screen_render", subviewport.get_texture())
        
func _unhandled_input(event: InputEvent) -> void:
    #if event is InputEventMouseMotion:
        #print("Mouse motion", event.position)
    subviewport.push_input(event)
