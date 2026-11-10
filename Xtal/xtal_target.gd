class_name XtalTarget

extends StaticBody3D

signal xtal_died(xtal: XtalTarget)

@export var health: int = 10

func take_damage(amount: int):
    if not health:
        print("Xtal took damage but is dead")
        return
    
    health -= amount
    if health <= 0:
        xtal_died.emit(self)
