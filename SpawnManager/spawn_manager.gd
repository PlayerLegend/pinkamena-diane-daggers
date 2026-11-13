class_name SpawnManager
extends Node

signal enemy_spawned(enemy: Node)

@export var schedule: SpawnSchedule
## Looped after the last event of `schedule`.
@export var repeat: SpawnSchedule
## Enemies are added as children of this node.
@export var spawn_parent: MultiplayerSpawner

var _events: Array[SpawnEvent]
var _next := 0
var _timer := 0.0

func _ready() -> void:
    print("SpawnManager at ", get_path(), " schedule=", schedule, " repeat=", repeat, " parent=", spawn_parent)
    _events = schedule.events
    if not _events.is_empty():
        _timer = _events[0].delay

func _physics_process(delta: float) -> void:
    if _events.is_empty():
        return
    _timer -= delta
    while _timer <= 0.0:
        _spawn(_events[_next])
        _next += 1
        if _next >= _events.size():
            if repeat == null or repeat.events.is_empty():
                _events = []
                return
            _events = repeat.events
            _next = 0
        _timer += _events[_next].delay

func _spawn(event: SpawnEvent) -> void:
    for scene in event.scenes:
        var enemy := scene.instantiate()
        spawn_parent.add_child(enemy)
        enemy_spawned.emit(enemy)
