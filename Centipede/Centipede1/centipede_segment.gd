class_name CentipedeSegment
extends PathFollow3D

@export var animation_player: AnimationPlayer

func _setup_animation(offset: float, length: float):
    var anim := animation_player.get_animation("staggered")

    animation_player.play("staggered")
    animation_player.seek(-offset * get_index())
    animation_player.speed_scale = length / anim.length
    animation_player.play()
    
func setup_wave(wave_count: float, segment_count: float, segment_spacing: float, follow_speed: float) -> void:
    var offset_per_segment: float = segment_spacing / follow_speed
    var animation_length: float = (segment_count * segment_spacing) / (follow_speed * wave_count)
    _setup_animation(offset_per_segment, animation_length)
