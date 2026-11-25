#pragma once

#include "BoidDefs.hpp"
#include <cmath>
#include <cstddef>

namespace godot {
class SpatialHashBase {
protected:
  static constexpr std::size_t array_width = (1 << 6);
  static constexpr std::size_t array_height = (1 << 4);
  static constexpr float CELL_WIDTH = BOID_NEIGHBOR_RADIUS * 2.0;

  using CellIndex = uint32_t;

  static int32_t f2i(float f) { return (int32_t)std::floor(f / CELL_WIDTH); }

  static CellIndex get_cell_index(int32_t cx, int32_t cy, int32_t cz) {
    constexpr CellIndex mask_xz = array_width - 1;
    constexpr CellIndex mask_y = array_height - 1;
    CellIndex x = (CellIndex)cx & mask_xz;
    CellIndex y = (CellIndex)cy & mask_y;
    CellIndex z = (CellIndex)cz & mask_xz;
    return (y * array_width + x) * array_width + z;
  }
};
} // namespace godot
