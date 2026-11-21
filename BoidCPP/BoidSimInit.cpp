#include "boidsim.hpp"

using namespace godot;

BoidSim::BoidSim() {
  array_position.resize(MAX_BOIDS);
  array_rotation.resize(MAX_BOIDS);
  array_velocity.resize(MAX_BOIDS);
  array_health.resize(MAX_BOIDS);
  array_type.resize(MAX_BOIDS);

  p_pos = array_position.ptrw();
  p_rot = array_rotation.ptrw();
  p_vel = array_velocity.ptrw();
  p_health = array_health.ptrw();
  p_type = array_type.ptrw();
}

BoidSim::~BoidSim() {
  // Add your cleanup here.
}
