#pragma once

#include <stdint.h>

namespace godot {
using BoidID = uint16_t;
static constexpr BoidID BOID_NULL = -1;
static constexpr BoidID MAX_BOIDS = 2000;
static constexpr float BOID_NEIGHBOR_RADIUS = 3.0;
static constexpr float BOID_SEPARATION = 0.5;
static constexpr float BOID_SEPARATION_SQUARED =
    BOID_SEPARATION * BOID_SEPARATION;

} // namespace godot
