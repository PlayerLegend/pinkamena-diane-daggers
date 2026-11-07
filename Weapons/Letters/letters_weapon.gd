extends BaseWeapon

class_name WeaponLetters

@export var projectile_scene: PackedScene
@export var projectile_source: Node3D

@onready var markov_chain: MarkovChain

var cooldown: float

const GLYPH_DIR := "res://Blend/Text/glyphs/"
const GLYPH_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
const UPPER_SUFFIX := "_upper"

## Maps single-character String -> Mesh.
var _glyph_meshes: Dictionary = {}
## First mesh that loaded successfully; used when a letter has no match.
var _fallback_mesh: Mesh = null

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
    var offset_dir: Vector3 = randf_range(-1, 1) * global_basis.x + randf_range(-1,1) * global_basis.y
    var offset = offset_dir.normalized() * randf_range(0,0.1)
    var dir = (-10.0 * global_basis.z + offset).normalized()
    new_projectile.set_path(projectile_source.global_position + offset, dir, global_basis.y)
    new_projectile.fly_finish_node = self
    new_projectile.mesh = _glyph_meshes.get(get_letter(), _fallback_mesh)
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
    _build_glyph_dict(GLYPH_CHARS)
    _refresh_passage()


## Returns true if the single-character string is an uppercase letter (A-Z).
func _is_upper_char(c: String) -> bool:
    var code := c.unicode_at(0)
    return code >= 65 and code <= 90


## Returns the glyph file path for a character.
## Uppercase letters use "<char>_upper.obj"; everything else uses "<char>.obj".
func _glyph_path(c: String) -> String:
    if _is_upper_char(c):
        return GLYPH_DIR + c + UPPER_SUFFIX + ".obj"
    return GLYPH_DIR + c + ".obj"


## Builds a dictionary of char -> Mesh, loading the glyph file for each char in the string.
## Uppercase letters are loaded from <char>_upper.obj.
## The first mesh that loads becomes the fallback.
func _build_glyph_dict(chars: String) -> void:
    for i in range(chars.length()):
        var c := chars[i]
        var path := _glyph_path(c)
        if ResourceLoader.exists(path):
            var mesh := load(path) as Mesh
            _glyph_meshes[c] = mesh
            if _fallback_mesh == null:
                _fallback_mesh = mesh


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
