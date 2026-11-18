class_name CentipedeSegment
extends Node3D

@export var animation_player: AnimationPlayer

signal xtal_died(xtal: XtalTarget)

var offset: float = 0.2
var anim_time: float

var last_position: Vector3

func _ready():
    var anim := animation_player.get_animation("staggered")

    animation_player.play("staggered")
    animation_player.speed_scale = 1.0 / anim.length
    animation_player.pause()
    
    for child in get_children():
        if child is XtalTarget:
            child.xtal_died.connect(_xtal_died)
    
func _process(_delta: float):
    var distance = (position - last_position).length()
    last_position = position
    anim_time += distance
    animation_player.seek(offset + anim_time / 4.0, true)
    
func _xtal_died(xtal: XtalTarget):
    xtal_died.emit(xtal)
    
