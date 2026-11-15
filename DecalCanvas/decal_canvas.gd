class_name DecalCanvas
extends Node3D

@export var arena_radius: float = 11.0 * 3.0
@export var texture_resolution: int = 2048
## Approximate size of a splatter in world units.
@export var splatter_world_size: float = 3.0
@export var splatter_choices: Array[CompressedTexture2D]
## How strongly the splatters glow. 0 disables emission.
@export_range(0.0, 2.0, 0.01, "or_greater") var emission_strength: float = 1.0

@export var splat_material: ShaderMaterial

@onready var sub_viewport: SubViewport = $SubViewport
@onready var decal: Decal = $Decal

func _ready() -> void:
    sub_viewport.size = Vector2i(texture_resolution, texture_resolution)
    sub_viewport.transparent_bg = true
    sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    # 1. Default filter for everything drawn inside the viewport.
    sub_viewport.canvas_item_default_texture_filter = \
        Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

    # 2. Decal sampling of the viewport texture (global, see note below).
    RenderingServer.decals_set_filter(RenderingServer.DECAL_FILTER_NEAREST)

    decal.size = Vector3.ONE * arena_radius * 2.0
    decal.emission_energy = emission_strength
    
    await _clear_canvas_to_transparent()


## Forces the viewport to render one empty frame so its texture is initialized
## to transparent. Without this, the texture is uninitialized GPU memory until
## the first splatter is drawn, which shows up as black on some drivers.
## The decal is hidden during the render to avoid a one-frame flash.
func _clear_canvas_to_transparent() -> void:
    decal.visible = false
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    await RenderingServer.frame_post_draw
    _refresh_decal_textures()
    decal.visible = true

func _refresh_decal_textures() -> void:
    var viewport_tex := sub_viewport.get_texture()
    decal.texture_albedo = viewport_tex
    decal.texture_emission = viewport_tex

func add_splatter(world_position: Vector3, splatter_scale: float = 1.0) -> void:
    assert(!splatter_choices.is_empty())

    var local_pos := to_local(world_position)
    var uv := Vector2(local_pos.x, local_pos.z) / (arena_radius * 2.0) + Vector2(0.5, 0.5)
    if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
        print("Splatter outside of uv")
        return

    var tex: Texture2D = splatter_choices.pick_random()
    var pixels_per_unit := texture_resolution / (arena_radius * 2.0)

    # Per-splatter random variation on top of the caller's scale.
    var random_coefficient := randf_range(0.5, 1.5)
    var world_size := splatter_world_size * splatter_scale * random_coefficient

    var sprite := Sprite2D.new()
    sprite.material = splat_material
    sprite.texture = tex
    # 3. Explicit per-sprite filter, so it doesn't depend on the parent default.
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = uv * texture_resolution
    sprite.rotation = randf() * TAU
    sprite.scale = Vector2.ONE * (world_size * pixels_per_unit / tex.get_width())
    sub_viewport.add_child(sprite)

    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    await RenderingServer.frame_post_draw

    # Re-assign to force the decal to pick up the updated viewport contents.
    decal.texture_albedo = null
    decal.texture_emission = null
    _refresh_decal_textures()

    sprite.queue_free()


#func _on_boid_removed(
    #type: BoidType,
    #_boid_mesh: Mesh,
    #pos: Vector3,
    #_velocity: Vector3,
    #_forward: Vector3,
    #health: int
    #):
        #if health <= 0:
            #add_splatter(pos, type.collision_radius * 5.0)
