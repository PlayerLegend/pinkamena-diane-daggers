#pragma once

#include "BoidDefs.hpp"
#include "BoidType.hpp"

#include <cstdint>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <vector>

namespace godot {
class BoidMMI : public Node {
  GDCLASS(BoidMMI, Node);

  static constexpr int TRANSFORM_FLOATS = 12;
  std::vector<Ref<MultiMesh>> multimeshes;
  PackedFloat32Array transforms;
  int current_type = -1;
  int current_transform = 0;
  float *p_transform = nullptr;

protected:
  static void _bind_methods() {}

public:
  void set_types(TypedArray<BoidType> boid_types);

  void start_type(uint16_t type_index);
  void set_transform(const Transform3D &transform);
  void finish_type(uint16_t type_index);

  void clear();
};
} // namespace godot
