class_name PlayerControllerWeapons

extends Node3D

@export var guide_action_shoot: GUIDEAction
@export var input: PlayerControllerInput

#var _active: bool

func _helper_use_weapon():
    if not input.is_multiplayer_authority():
        return
        
    for child in get_children():
        if child is NetworkWeapon3D:
            if not child.can_fire():
                continue
            print("Use weapon")
            child.fire()
            break
        
func _ready():
    guide_action_shoot.triggered.connect(_helper_use_weapon)
    
