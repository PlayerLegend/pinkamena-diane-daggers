#include "boidsim.hpp"

using namespace godot;

int BoidSim::add_boid(int t, Vector3 pos, Quaternion r, Vector3 vel, int hp) {
  BoidID id = boid_arrays.add_boid(t, pos, r, vel, hp);
  return id == BOID_NULL ? -1 : (int)id;
}
void BoidSim::remove(int boid) {
  if (boid >= 0 && boid < MAX_BOIDS)
    boid_arrays.remove_boid((BoidID)boid);
}
