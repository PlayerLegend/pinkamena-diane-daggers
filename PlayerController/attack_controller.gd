class_name PlayerControllerWeapons

extends Node3D

@export var guide_action_shoot: GUIDEAction
@export var input: PlayerControllerInput
@export var projectile_parent: Node

#var _active: bool

func _helper_use_weapon():
    if not input.is_multiplayer_authority():
        return
        
    if not projectile_parent:
        return
        
    for child in get_children():
        if child is BaseWeapon:
            if not child.can_fire():
                continue
            child.projectile_parent = projectile_parent
            child.fire()
            break
        
func _ready():
    guide_action_shoot.triggered.connect(_helper_use_weapon)
    
