#pragma once

#include "BoidDefs.hpp"
#include "SpatialHash.hpp"
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {
class FlockingSum : public SpatialHashBase {
  // spatial hash sums, does wrap

  uint32_t tick = 0;

public:
  struct Sum {
    uint32_t tick = -1;
    BoidID count = 0;
    Vector3 position;
    Vector3 velocity;

    Vector3 get_position(Vector3 self) const {
      if (count < 2)
        return self;
      return position / float(count - 1);
    }
    Vector3 get_velocity() const {
      if (count < 2)
        return Vector3{};
      return velocity / float(count - 1);
    }
  };

  void set_sums(BoidID boid_count, const PackedVector3Array &array_position,
                const PackedVector3Array &array_velocity);

  Sum get_sum(Vector3 pos);

private:
  std::array<Sum, array_width * array_width * array_height> sums;
};
} // namespace godot
