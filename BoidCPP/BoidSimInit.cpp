#include "boidsim.hpp"

using namespace godot;

BoidSim::BoidSim() : boid_arrays(nearby_lookup) {}

BoidSim::~BoidSim() {
  // Add your cleanup here.
}
