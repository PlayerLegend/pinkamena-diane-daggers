class_name GameWorld
extends Node3D

@export var player_light: bool
signal world_finished(next_world: PackedScene)
signal requested_sound(sound: AudioStream)

var time: float

func finish_world(next_world: PackedScene):
    world_finished.emit(next_world)

func _process(delta: float):
    time += delta

func _helper_find_spawn() -> Transform3D:
    var spawn = get_tree().get_nodes_in_group("player_spawns").pick_random()
    if spawn:
        return spawn.global_transform
    else:
        return Transform3D.IDENTITY

func add_player(player: PlayerController):
    player.teleport(_helper_find_spawn())
    player.enable_light = player_light

func play_sound(sound: AudioStream):
    requested_sound.emit(sound)
