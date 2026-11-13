extends GameWorld

@onready var omni_light_3d: OmniLight3D = $OmniLight3D

@onready var _light_energy_target: float
@onready var projectile_parent: Node3D = $ProjectileParent

func _ready():
    _light_energy_target = omni_light_3d.light_energy
    omni_light_3d.light_energy = 0

func _process(delta: float) -> void:
    super(delta)
    omni_light_3d.light_energy = lerp(
        omni_light_3d.light_energy, 
        _light_energy_target, 
        delta * 6
    )

func add_player(player: PlayerController):
    super(player)
    player.projectile_parent = projectile_parent
    print("Tried to set projectile parent ", projectile_parent)
    player.visible = true
