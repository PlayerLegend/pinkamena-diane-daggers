class_name XtalTarget

extends StaticBody3D

signal xtal_died(xtal: XtalTarget)

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var hit_sound: AudioStreamPlayer3D = $HitSound

@export var health: int = 10

func _now() -> float:
    return Time.get_ticks_msec() * 0.001

func flash():
    mesh_instance_3d.set_instance_shader_parameter("flash_end", _now() + 1.0 / 20.0)

func take_damage(amount: int):
    if health <= 0:
        print("Xtal took damage but is dead")
        return

    health -= amount
    flash()
    hit_sound.play()
    if health <= 0:
        xtal_died.emit(self)
