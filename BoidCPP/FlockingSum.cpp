#include "boidsim.hpp"

using namespace godot;

void BoidSim::FlockingSum::set_sums(BoidID boid_count,
                                    const PackedVector3Array &array_position,
                                    const PackedVector3Array &array_velocity) {
  tick++;

  const Vector3 *p_pos = array_position.ptr();
  const Vector3 *p_vel = array_velocity.ptr();

  for (size_t i = 0; i < boid_count; i++) {
    const Vector3 &pos = p_pos[i];
    const Vector3 &vel = p_vel[i];
    Sum &sum = sums[get_cell_index(f2i(pos.x), f2i(pos.y), f2i(pos.z))];

    if (sum.tick != tick) {
      sum = Sum{tick};
    }

    sum.position += pos;
    sum.velocity += vel;

    sum.count++;
  }
}

BoidSim::FlockingSum::Sum BoidSim::FlockingSum::get_sum(Vector3 pos) {
  const int32_t x0 = f2i(pos.x - BOID_NEIGHBOR_RADIUS);
  const int32_t y0 = f2i(pos.y - BOID_NEIGHBOR_RADIUS);
  const int32_t z0 = f2i(pos.z - BOID_NEIGHBOR_RADIUS);

  Sum total;

  for (int32_t dy = 0; dy <= 1; dy++)
    for (int32_t dx = 0; dx <= 1; dx++)
      for (int32_t dz = 0; dz <= 1; dz++) {
        const Sum &s = sums[get_cell_index(x0 + dx, y0 + dy, z0 + dz)];

        if (s.tick != tick)
          continue;

        total.count += s.count;
        total.position += s.position;
        total.velocity += s.velocity;
      }

  return total;
}
