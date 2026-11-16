extends Node

@export var time_seek_node_name: String = "TimeSeek"
@export var animation_node_name: String = "staggered"
@export var animation_offset: float = 0.05
@export var animation_speed: float = 4.0
@onready var animation_player: AnimationPlayer = $CentipedeSegment/AnimationPlayer

func _set_offset():
    var anim := animation_player.get_animation("staggered")

    animation_player.play("staggered")
    animation_player.seek(-animation_offset * get_index())
    animation_player.speed_scale = animation_speed / anim.length
    #animation_player.play()

func _ready():
    #pass
    _set_offset.call_deferred()
