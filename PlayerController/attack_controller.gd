class_name PlayerControllerWeapons

extends Node3D

@export var guide_action_shoot: GUIDEAction
@export var input: PlayerControllerInput
@export var projectile_parent: Node

var attack_charge: float
var attack_pressed: bool
var attack_released: bool

@export var attack_stream_threshold: float = 0.1
@export var attack_shot_setback: float = -0.1

var attack_power: int
#var _active: bool

#func _helper_use_weapon():

func _fire_shot():
    attack_charge = attack_shot_setback
    
    if not projectile_parent:
        return
        
    for child in get_children():
        if child is WeaponLettersShot:
            assert(child.can_fire())
            child.projectile_parent = projectile_parent
            for i in range(10):
                child.fire()
            break


func _fire_stream():
    if not projectile_parent:
        print("no proj parent")
        return
    for child in get_children():
        if child is WeaponLettersStream:
            if not child.can_fire():
                continue
            child.projectile_parent = projectile_parent
            child.fire()
            break


func _process(delta: float):
    
    if not input.is_multiplayer_authority():
        return
    
    if attack_pressed:
        attack_charge = min(attack_charge + delta, attack_stream_threshold)
        if attack_charge == attack_stream_threshold:
            _fire_stream()
    
    if attack_released:
        if attack_charge < attack_stream_threshold:
            _fire_shot()
        
    if attack_released:
        attack_pressed = false
        attack_released = false
    
    if not attack_pressed:
        if attack_charge < -delta:
            attack_charge += delta  
        elif attack_charge > delta:
            attack_charge -= delta
        else:
            attack_charge = 0
        
func _start_attack():
    attack_pressed = true
    
func _finish_attack():
    attack_released = true

func _ready():
    guide_action_shoot.just_triggered.connect(_start_attack)
    guide_action_shoot.completed.connect(_finish_attack)
