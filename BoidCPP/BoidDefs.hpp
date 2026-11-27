#pragma once

#include <stdint.h>

namespace godot {
using BoidID = uint16_t;
static constexpr BoidID BOID_NULL = -1;
static constexpr BoidID MAX_BOIDS = 10000;
static constexpr float BOID_NEIGHBOR_RADIUS = 3.0;
static constexpr float BOID_NEIGHBOR_RADIUS_SQUARED =
    BOID_NEIGHBOR_RADIUS * BOID_NEIGHBOR_RADIUS;
static constexpr float BOID_SEPARATION = 1.0;
static constexpr float BOID_SEPARATION_SQUARED =
    BOID_SEPARATION * BOID_SEPARATION;

static constexpr float BOID_AVOIDANCE_RADIUS = 3.0;
static constexpr float BOID_AVOIDANCE_RADIUS_SQUARED =
    BOID_AVOIDANCE_RADIUS * BOID_AVOIDANCE_RADIUS;

} // namespace godot
