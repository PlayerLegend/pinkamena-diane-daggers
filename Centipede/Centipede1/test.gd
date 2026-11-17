extends Node3D
@onready var centipede_1: Centipede = $Centipede1

var time: float
var cooldown: float
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

var peer

func _ready() -> void:
    peer = ENetMultiplayerPeer.new()
    peer.create_server(7000)
    multiplayer.multiplayer_peer = peer
    
func get_figure8_transform(t: float, size: float, roll_speed: float) -> Transform3D:
    var pos = Vector3(cos(t), 0, sin(t) * cos(t)) * size
    
    var tangent = Vector3(
        -sin(t),
        0,
        cos(t) * cos(t) - sin(t) * sin(t)
    )
    
    var target_basis = Basis.looking_at(tangent, Vector3.UP)
    target_basis = target_basis.rotated(target_basis.z, t * roll_speed)  # roll around local forward
    
    return Transform3D(target_basis, pos)
    
func _process(delta: float):
    time += delta
    cooldown -= delta
    
    if cooldown < 0:
        mesh_instance_3d.transform = get_figure8_transform(time, 10, 5)
    
        centipede_1.target = get_figure8_transform(time, 10, 5)
            
