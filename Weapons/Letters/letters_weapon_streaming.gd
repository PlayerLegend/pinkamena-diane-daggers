class_name WeaponLettersStream
extends WeaponLetters

var rate: float = 20.0
var cooldown: float

func _process(delta: float):
    cooldown = max(0, cooldown - delta)

func _can_fire() -> bool:
    if cooldown > 0:
        return false
        
    return true

func _after_fire(_projectile: Node):
    cooldown = 1.0 / rate
    
