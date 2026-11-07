extends BaseWeapon

class_name WeaponLetters

@export var projectile_scene: PackedScene
@export var projectile_source: Node3D

@onready var markov_chain: MarkovChain

var cooldown: float

## Filtered passage (letters and numbers only) that letters are read from.
var _cached_passage: String = ""
## Index of the next character to hand out from the cached passage.
var _letter_index: int = 0

func _process(delta: float):
    cooldown = max(0, cooldown - delta)

func _can_fire() -> bool:
    if cooldown > 0:
        return false
        
    return true

func _can_peer_use(_peer_id: int) -> bool:
    return true
    
func _after_fire(_projectile: Node):
    cooldown = 60.0 / 900.0
    
func _spawn() -> Node3D:
    var new_projectile: LetterProjectile = projectile_scene.instantiate()
    new_projectile.add_to_group("LetterProjectiles")
    add_child(new_projectile)
    new_projectile.set_path(projectile_source.global_position, -global_basis.z, global_basis.y)
    new_projectile.fly_finish_node = self
    new_projectile.glyph = get_letter()
    print(new_projectile.glyph)
    return new_projectile

func _get_data(projectile: Node) -> Dictionary:
    return projectile.serialize()

func _apply_data(projectile: Node, data: Dictionary):
    projectile.deserialize(data, global_basis.y)

func _is_reconcilable(_projectile: Node, _request_data: Dictionary, _local_data: Dictionary) -> bool:
    return true

func _reconcile(_projectile: Node, _local_data: Dictionary, _remote_data: Dictionary):
    pass

func _ready() -> void:
    markov_chain = MarkovChain.new(2)
    markov_chain.load_from_file("res://passages.txt")
    _refresh_passage()


## Returns the next letter/number from the cached passage.
## When the cache runs out, a new passage is generated from the Markov chain.
func get_letter() -> String:
    if _letter_index >= _cached_passage.length():
        _refresh_passage()
        if _cached_passage.is_empty():
            return ""  # Nothing usable could be generated.

    var letter := _cached_passage[_letter_index]
    _letter_index += 1
    return letter


## Generates a new passage, filters it, and stores it in the cache.
## Retries a few times in case a passage filters down to nothing.
func _refresh_passage(max_attempts: int = 5) -> void:
    _cached_passage = ""
    _letter_index = 0

    if markov_chain == null or not markov_chain.is_trained():
        return

    for i in range(max_attempts):
        var filtered := filter_passage(markov_chain.generate())
        if not filtered.is_empty():
            _cached_passage = filtered
            return


## Removes everything except letters and numbers (A-Z, a-z, 0-9).
func filter_passage(passage: String) -> String:
    var result := ""
    for i in range(passage.length()):
        var c := passage.unicode_at(i)
        var is_digit := c >= 48 and c <= 57
        var is_upper := c >= 65 and c <= 90
        var is_lower := c >= 97 and c <= 122
        if is_digit or is_upper or is_lower:
            result += passage[i]
    return result
