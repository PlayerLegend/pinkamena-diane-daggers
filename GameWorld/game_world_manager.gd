class_name GameWorldManager
extends Node3D

signal world_changed(new_world: GameWorld)

@export var game_world: GameWorld:
    set(value):
        if game_world == value:
            return
            
        if game_world:
            game_world.queue_free()
            
        if value is GameWorld:
            add_child(value)
            value.world_finished.connect(_on_world_finished)
            
        game_world = value
        world_changed.emit(value)

func add_player(player: PlayerController):
    assert(game_world)
    game_world.add_player(player)

func _on_world_finished(next_world: PackedScene):
    game_world = next_world.instantiate()
