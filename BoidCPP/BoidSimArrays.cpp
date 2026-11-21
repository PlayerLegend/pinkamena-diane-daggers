#include "boidsim.hpp"

using namespace godot;

void BoidSim::set_position(int boid, Vector3 pos) {
  if (boid >= boid_count || boid < 0)
    return;
  nearby_lookup.insert(boid, pos);
  p_pos[boid] = pos;
}

int BoidSim::add_boid(int type_index, Vector3 pos, Quaternion r,
                      Vector3 velocity, int health) {

  if (boid_count >= MAX_BOIDS)
    return -1;

  if (type_index >= boid_types.size() || type_index < 0)
    return -1;

  BoidID boid = boid_count;
  boid_count++;

  set_position(boid, pos);
  p_rot[boid] = Vector4(r.x, r.y, r.z, r.w);
  p_vel[boid] = velocity;
  p_health[boid] = health;
  p_type[boid] = type_index;

  return boid;
}

void BoidSim::remove(int boid) {
  if (boid >= boid_count || boid < 0)
    return;

  BoidID last_boid = boid_count - 1;

  set_position(boid, p_pos[last_boid]);
  p_rot[boid] = p_rot[last_boid];
  p_vel[boid] = p_vel[last_boid];
  p_health[boid] = p_health[last_boid];
  p_type[boid] = p_type[last_boid];

  nearby_lookup.unlink(last_boid);

  boid_count = last_boid;
}
