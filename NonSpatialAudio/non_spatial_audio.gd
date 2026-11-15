class_name MultiVoicePlayer
extends Node
## Plays non-spatial sounds with a fixed number of simultaneous voices.
## Add this node to a scene (or make it an Autoload) and call play_sound().

@export_range(1, 64) var voices: int = 8
@export var bus: StringName = &"Master"

var _players: Array[AudioStreamPlayer] = []
var _next_steal := 0


func _ready() -> void:
    for i in voices:
        var player := AudioStreamPlayer.new()
        player.bus = bus
        add_child(player)
        _players.append(player)


## Plays a stream on a free voice. If every voice is busy, the oldest
## voice is stolen (round-robin). Returns the player used, so you can
## stop it or tweak it later.
func play_sound(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
    if stream == null:
        return null

    var player := _get_free_player()
    player.stream = stream
    player.volume_db = volume_db
    player.pitch_scale = pitch_scale
    player.play()
    return player


## Stops every voice.
func stop_all() -> void:
    for player in _players:
        player.stop()


func _get_free_player() -> AudioStreamPlayer:
    for player in _players:
        if not player.playing:
            return player

    # All voices busy: steal the next one in rotation.
    var stolen := _players[_next_steal]
    _next_steal = (_next_steal + 1) % _players.size()
    return stolen
