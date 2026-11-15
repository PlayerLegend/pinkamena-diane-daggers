class_name GameWorldManager
extends Node3D

@export var sound_manager: MultiVoicePlayer

signal world_changed(new_world: GameWorld)

@export var game_world: GameWorld:
    set(value):
        
        assert(value is GameWorld or not value)
        
        if game_world == value:
            return
            
        if game_world:
            game_world.queue_free()
            
        if value is GameWorld:
            add_child(value)
            value.world_finished.connect(_on_world_finished)
            value.requested_sound.connect(_on_play_sound)
            
        game_world = value
        world_changed.emit(value)

func add_player(player: PlayerController):
    assert(game_world)
    game_world.add_player(player)

func _on_world_finished(next_world: PackedScene):
    game_world = next_world.instantiate()

func _on_play_sound(sound: AudioStream):
    sound_manager.play_sound(sound)

func _ready():
    assert(sound_manager)
