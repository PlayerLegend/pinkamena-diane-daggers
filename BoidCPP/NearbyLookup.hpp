#pragma once

#include "BoidDefs.hpp"
#include "SpatialHash.hpp"
#include <array>
#include <cmath>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {
class NearbyLookup : public SpatialHashBase {
  struct BoidLink {
    static constexpr uint32_t CELL_NULL = -1;
    BoidID prev = BOID_NULL;
    BoidID next = BOID_NULL;
    uint32_t cell_index = CELL_NULL;
  };
  std::array<BoidLink, MAX_BOIDS> links;
  std::array<BoidID, array_width * array_width * array_height> table;

public:
  NearbyLookup() {
    for (BoidID &i : table)
      i = BOID_NULL;
  }

  void unlink(BoidID id);
  void insert(uint16_t boid, Vector3 pos);

  BoidID lookup_cell(Vector3 pos) {
    return table[get_cell_index(f2i(pos.x), f2i(pos.y), f2i(pos.z))];
  }

  std::array<BoidID, 8> lookup_area(Vector3 pos) {
    const int32_t x0 = f2i(pos.x - BOID_NEIGHBOR_RADIUS);
    const int32_t y0 = f2i(pos.y - BOID_NEIGHBOR_RADIUS);
    const int32_t z0 = f2i(pos.z - BOID_NEIGHBOR_RADIUS);

    std::array<BoidID, 8> heads;
    int n = 0;
    for (int32_t dy = 0; dy <= 1; dy++)
      for (int32_t dx = 0; dx <= 1; dx++)
        for (int32_t dz = 0; dz <= 1; dz++)
          heads[n++] = table[get_cell_index(x0 + dx, y0 + dy, z0 + dz)];
    return heads;
  }

  BoidID next(BoidID boid) {
    if (boid < MAX_BOIDS)
      return links[boid].next;
    return BOID_NULL;
  }
};
} // namespace godot
