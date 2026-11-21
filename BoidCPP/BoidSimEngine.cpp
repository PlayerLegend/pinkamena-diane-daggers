#include "boidsim.hpp"
#include <godot_cpp/classes/engine.hpp>

using namespace godot;

void BoidSim::_bind_methods() {
  ClassDB::bind_method(D_METHOD("add_boid", "type_index", "pos", "rotation",
                                "velocity", "health"),
                       &BoidSim::add_boid);
  ClassDB::bind_method(D_METHOD("remove", "boid"), &BoidSim::remove);
  ClassDB::bind_method(D_METHOD("raycast", "origin", "direction"),
                       &BoidSim::raycast);
  ClassDB::bind_method(D_METHOD("set_types", "types"), &BoidSim::set_types);
  ClassDB::bind_method(D_METHOD("get_types"), &BoidSim::get_types);
  ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "types", PROPERTY_HINT_TYPE_STRING,
                            String::num_int64(Variant::OBJECT) + "/" +
                                String::num_int64(PROPERTY_HINT_RESOURCE_TYPE) +
                                ":BoidType"),
               "set_types", "get_types");
}

void BoidSim::set_types(TypedArray<BoidType> t) {
  types = t;
  boid_arrays.set_types(t); // asserts boid_count == 0
  if (!boid_mmi) {
    boid_mmi = memnew(BoidMMI);
    add_child(boid_mmi);
  }
  boid_mmi->set_types(t);
}

void BoidSim::_physics_process(double delta) {
  if (Engine::get_singleton()->is_editor_hint())
    return;
  _tick(delta);
}
