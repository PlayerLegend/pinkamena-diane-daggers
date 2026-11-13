class_name PreambleWorld
extends GameWorld
@onready var start_game_trigger: Area3D = $StartGameTrigger

@onready var omni_light_3d: OmniLight3D = $OmniLight3D

@onready var _light_energy_target: float = omni_light_3d.light_energy
@onready var arena: Node3D = $Arena

@export var next_world: PackedScene

func _ready() -> void:
    start_game_trigger.body_entered.connect(_on_start_game_trigger_body_entered)

func _process(delta: float) -> void:
    omni_light_3d.light_energy = lerp(
        omni_light_3d.light_energy, 
        _light_energy_target, 
        delta * 6
    )
    if omni_light_3d.light_energy < 0.001:
        change_world.emit(next_world)
    
        
func _on_start_game_trigger_body_entered(body: Node3D) -> void:
    if arena.time < 0.2:
        return
    if body is PlayerController:
        _light_energy_target = 0
