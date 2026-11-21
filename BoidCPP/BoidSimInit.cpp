#include "boidsim.hpp"

using namespace godot;

BoidSim::BoidSim() {
  array_position.resize(MAX_BOIDS);
  array_rotation.resize(MAX_BOIDS);
  array_velocity.resize(MAX_BOIDS);
  array_health.resize(MAX_BOIDS);
  array_steering_flock.resize(MAX_BOIDS);

  type_end.resize(boid_types.size());
  type_stopped_prev.resize(boid_types.size());

  p_pos = array_position.ptrw();
  p_rot = array_rotation.ptrw();
  p_vel = array_velocity.ptrw();
  p_health = array_health.ptrw();
  p_steer_flock = array_steering_flock.ptrw();
}

BoidSim::~BoidSim() {
  // Add your cleanup here.
}
