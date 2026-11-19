class_name MainGameWorld
extends GameWorld

@onready var omni_light_3d: OmniLight3D = $OmniLight3D

@onready var _light_energy_target: float
@onready var projectile_parent: Node3D = $ProjectileParent
@onready var boid_manager: BoidManager = $BoidManager
@export var menu_world: PackedScene
@export var game_over_screen: Control
signal player_died(player: PlayerController, stats: GameOverStats)
@onready var decal_canvas: DecalCanvas = $DecalCanvas

func _ready():
    _light_energy_target = omni_light_3d.light_energy
    omni_light_3d.light_energy = 0
func _check_for_deaths():
    if time < 0.5:
        return
    for node in get_tree().get_nodes_in_group("chase_targets"):
        if node is PlayerController:
            decal_canvas.add_splatter(node.position)
            if not node.visible:
                continue
            if node.global_position.y < -10:
                var stats := GameOverStats.new()
                stats.time = time
                stats.power = node.attack_power
                stats.death_type = "Fallen"
                player_died.emit(node, stats)
            var boid = boid_manager.get_boid_at_point(node.position)
            if boid >= 0:
                var boid_type: BoidType = boid_manager.get_boid_type(boid)
                var stats := GameOverStats.new()
                stats.time = time
                stats.power = node.attack_power
                stats.death_type = boid_type.death_type
                player_died.emit(node, stats)
        
         
func _physics_process(_delta: float) -> void:
    _check_for_deaths()
    
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
    player.attack_power = 0
