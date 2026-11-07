class_name LettersProjectileManager
extends Node3D
## Renders all LetterProjectile children through one MultiMeshInstance3D per glyph.

const GLYPH_DIR := "res://Blend/Text/glyphs/"
const INITIAL_CAPACITY := 64

const PROJECTILE_GROUP := "LetterProjectiles"

## Preferred stand-in for missing glyphs. If it isn't loaded, the first loaded glyph is used.
const FALLBACK_GLYPH := "?"

## glyph (String) -> MultiMeshInstance3D
var glyph_instances: Dictionary = {}


func _ready() -> void:
    _load_glyphs()


func _load_glyphs() -> void:
    var dir := DirAccess.open(GLYPH_DIR)
    if dir == null:
        push_error("LettersProjectileManager: can't open %s" % GLYPH_DIR)
        return

    for file_name in dir.get_files():
        # In exported builds, resources show up as .import / .remap files.
        var f := file_name.trim_suffix(".import").trim_suffix(".remap")
        if f.get_extension().to_lower() != "glb":
            continue

        var glyph := f.get_basename()
        if glyph_instances.has(glyph):
            continue

        var scene := load(GLYPH_DIR + f) as PackedScene
        if scene == null:
            push_warning("LettersProjectileManager: failed to load %s" % f)
            continue

        var root := scene.instantiate()
        var mesh_instance := _find_mesh_instance(root)
        if mesh_instance == null or mesh_instance.mesh == null:
            push_warning("LettersProjectileManager: no mesh found in %s" % f)
            root.free()
            continue

        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D  # must be set before instance_count
        mm.mesh = mesh_instance.mesh
        mm.instance_count = INITIAL_CAPACITY
        mm.visible_instance_count = 0

        var mmi := MultiMeshInstance3D.new()
        mmi.name = "Glyph_" + glyph
        mmi.multimesh = mm
        add_child(mmi)

        glyph_instances[glyph] = mmi
        root.free()


func _find_mesh_instance(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D:
        return node
    for child in node.get_children():
        var found := _find_mesh_instance(child)
        if found:
            return found
    return null


func _get_fallback_glyph() -> String:
    if glyph_instances.has(FALLBACK_GLYPH):
        return FALLBACK_GLYPH
    if not glyph_instances.is_empty():
        return glyph_instances.keys()[0]
    return ""
    
func _process(_delta: float) -> void:
    # Bucket projectile transforms by glyph.
    var buckets: Dictionary = {}

    for node in get_tree().get_nodes_in_group(PROJECTILE_GROUP):
        var projectile := node as LetterProjectile
        if projectile == null or projectile.is_queued_for_deletion():
            continue

        var glyph := str(projectile.glyph)
        if not glyph_instances.has(glyph):
            push_warning("LettersProjectileManager: no glyph mesh for '%s', using fallback" % glyph)
            glyph = _get_fallback_glyph()
            if glyph.is_empty():
                continue  # nothing loaded at all

        if not buckets.has(glyph):
            buckets[glyph] = []
        buckets[glyph].append(projectile.global_transform)

    # Push transforms into each multimesh.
    for glyph in glyph_instances:
        var mm: MultiMesh = glyph_instances[glyph].multimesh
        var xforms: Array = buckets.get(glyph, [])
        var count := xforms.size()

        if count > mm.instance_count:
            mm.instance_count = nearest_po2(count)  # grow by doubling; resets visible count

        mm.visible_instance_count = count
        for i in count:
            mm.set_instance_transform(i, xforms[i])
