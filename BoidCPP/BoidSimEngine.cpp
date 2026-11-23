#include "boidsim.hpp"
#include <godot_cpp/classes/engine.hpp>

using namespace godot;

void BoidSim::set_types(TypedArray<BoidType> t) {
  types = t;
  _apply_types();
}
void BoidSim::set_boid_arrays(BoidArrays *p) {
  boid_arrays = p;
  _apply_types();
}
void BoidSim::set_boid_mmi(BoidMMI *p) {
  boid_mmi = p;
  _apply_types();
}

void BoidSim::_apply_types() {
  if (types.is_empty())
    return;
  if (boid_arrays)
    boid_arrays->set_types(types);
  if (boid_mmi)
    boid_mmi->set_types(types);
}

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

  ClassDB::bind_method(D_METHOD("set_boid_arrays", "boid_arrays"),
                       &BoidSim::set_boid_arrays);
  ClassDB::bind_method(D_METHOD("get_boid_arrays"), &BoidSim::get_boid_arrays);
  ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "boid_arrays",
                            PROPERTY_HINT_NODE_TYPE, "BoidArrays"),
               "set_boid_arrays", "get_boid_arrays");

  ClassDB::bind_method(D_METHOD("set_boid_mmi", "boid_mmi"),
                       &BoidSim::set_boid_mmi);
  ClassDB::bind_method(D_METHOD("get_boid_mmi"), &BoidSim::get_boid_mmi);
  ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "boid_mmi",
                            PROPERTY_HINT_NODE_TYPE, "BoidMMI"),
               "set_boid_mmi", "get_boid_mmi");
}

void BoidSim::_physics_process(double delta) {
  if (Engine::get_singleton()->is_editor_hint())
    return;
  _tick(delta);
}
