extends RefCounted

class_name PhysicsCollision

var motion: Vector3
var normal_total: Vector3
var normals: Array[Vector3]
var ground_normal: Vector3
var others: Array[Node3D]

func has_normal(direction: Vector3, threshold: float) -> bool:
    for normal in normals:
        if normal.dot(direction) > threshold:
            return true
    return false
    
func get_normal(direction: Vector3, threshold: float):
    for normal in normals:
        if normal.dot(direction) > threshold:
            return normal
