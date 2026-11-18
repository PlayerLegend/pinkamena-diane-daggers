extends Centipede

var target: Transform3D

#func _process(_delta: float):
    #super(_delta)
    #transform = target
    #

func _rollback_tick(delta: float, tick, is_fresh):
    transform = target
    super(delta, tick, is_fresh)
    
    
