class_name DampedOscillatorFloat
extends RefCounted

var stiffness: float
var damping: float
var position: float
var velocity: float
var acceleration: float

func _init(stiff: float, damp: float =-1.0):
    stiffness = stiff
    damping = damp
    if damping < 0.0:
        damping = 2 * sqrt(stiffness)

var delta: float:
    set(value):
        delta = value
        acceleration = -stiffness * position - damping * velocity
        velocity += acceleration * delta
        position += velocity * delta
