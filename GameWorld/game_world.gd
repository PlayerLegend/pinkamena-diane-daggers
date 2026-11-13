class_name GameWorld
extends Node3D

@export var player_light: bool
signal world_finished(next_world: PackedScene)

var time: float

func _process(delta: float):
    time += delta

func _helper_find_spawn() -> Node3D:
    return get_tree().get_nodes_in_group("player_spawns").pick_random()

func add_player(player: PlayerController):
    var target_spawn = _helper_find_spawn()
    if target_spawn:
        player.transform = target_spawn.transform
        player.enable_light = player_light
