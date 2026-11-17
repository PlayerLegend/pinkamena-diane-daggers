extends Centipede

var target: Transform3D

func _rollback_tick(delta: float, tick, is_fresh):
    print("Test centipede rollback")
    transform = target
    super(delta, tick, is_fresh)
    
    
