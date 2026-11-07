extends OmniLight3D

@export var _noise: NoiseTexture3D
@export var flicker_rate: float = 3.0
@export var flicker_min: float = 1.0
@export var flicker_scale: float = 1.2

var time: float

func _process(delta: float):
    time += delta
    light_energy = flicker_min + flicker_min * (1.0 - flicker_scale) * _noise.noise.get_noise_1d(flicker_rate * time)
