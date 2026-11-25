#pragma once

#include "BoidDefs.hpp"
#include "SpatialHash.hpp"
#include <array>
#include <cmath>
#include <godot_cpp/variant/vector3.hpp>
#include <vector>

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

  class Results {
    std::array<BoidID, 8> heads;
    NearbyLookup &parent;
    uint8_t head_index = 0;
    Vector3 position;

  public:
    BoidID next() {
      while (head_index < 8) {
        BoidID head = heads[head_index];
        if (head < MAX_BOIDS) {
          heads[head_index] = parent.next(head);
          return head;
        }
        head_index++;
      }
      return BOID_NULL;
    }

    void fill_vector(std::vector<BoidID> &dest, const Vector3 *positions,
                     double radius) {
      dest.resize(0);
      BoidID boid;

      while ((boid = next()) < MAX_BOIDS) {
        Vector3 offset = position - positions[boid];

        if (offset.length_squared() < BOID_NEIGHBOR_RADIUS_SQUARED)
          dest.push_back(boid);
      }
    }

    Results(NearbyLookup &p, Vector3 pos)
        : parent(p), heads(p.lookup_area(pos)), position(pos) {}
  };

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
