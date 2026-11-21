#include "boidsim.hpp"
#include <godot_cpp/variant/typed_array.hpp>

using namespace godot;

void BoidMMI::set_types(TypedArray<BoidType> boid_types, int p_max_boids) {
  // Tear down anything from a previous call.
  TypedArray<Node> old_children = get_children();
  for (int i = 0; i < old_children.size(); i++) {
    if (MultiMeshInstance3D *mmi =
            Object::cast_to<MultiMeshInstance3D>(old_children[i])) {
      remove_child(mmi);
      mmi->queue_free();
    }
  }
  multimeshes.clear();
  p_transform = nullptr;
  current_type = -1;
  current_transform = 0;

  max_boids = p_max_boids < 0 ? 0 : p_max_boids;

  for (int i = 0; i < boid_types.size(); i++) {
    Ref<BoidType> type = boid_types[i];

    Ref<MultiMesh> mm;
    mm.instantiate();
    mm->set_transform_format(MultiMesh::TRANSFORM_3D);
    mm->set_use_colors(false);
    mm->set_use_custom_data(false);
    if (type.is_valid())
      mm->set_mesh(type->get_mesh());
    // Allocate once; visible_instance_count controls how many are drawn.
    mm->set_instance_count(max_boids);
    mm->set_visible_instance_count(0);

    MultiMeshInstance3D *mmi = memnew(MultiMeshInstance3D);
    mmi->set_multimesh(mm);
    if (type.is_valid() && type->get_material_override().is_valid())
      mmi->set_material_override(type->get_material_override());

    add_child(mmi);
    multimeshes.push_back(mm);
  }

  transforms.resize((int64_t)max_boids * TRANSFORM_FLOATS);
}

void BoidMMI::start_type(uint16_t type_index) {
  if (type_index >= multimeshes.size()) {
    current_type = -1;
    p_transform = nullptr;
    return;
  }
  current_type = type_index;
  current_transform = 0;
  // Re-fetch every time: set_buffer may have shared the array, and ptrw()
  // detaches it if so.
  p_transform = transforms.ptrw();
}

void BoidMMI::set_transform(Transform3D transform) {
  if (current_type < 0 || !p_transform || current_transform >= max_boids)
    return;

  float *dest = p_transform + current_transform * TRANSFORM_FLOATS;
  const Basis &b = transform.basis;
  const Vector3 &o = transform.origin;

  dest[0] = b.rows[0].x;
  dest[1] = b.rows[0].y;
  dest[2] = b.rows[0].z;
  dest[3] = o.x;
  dest[4] = b.rows[1].x;
  dest[5] = b.rows[1].y;
  dest[6] = b.rows[1].z;
  dest[7] = o.y;
  dest[8] = b.rows[2].x;
  dest[9] = b.rows[2].y;
  dest[10] = b.rows[2].z;
  dest[11] = o.z;

  current_transform++;
}

void BoidMMI::finish_type(uint16_t type_index) {
  if (type_index >= multimeshes.size() || type_index != current_type)
    return;

  const Ref<MultiMesh> &mm = multimeshes[type_index];
  // Buffer is always max_boids * 12 floats; entries past the visible count
  // are stale and never drawn.
  mm->set_buffer(transforms);
  mm->set_visible_instance_count(current_transform);

  current_type = -1;
  p_transform = nullptr;
}
