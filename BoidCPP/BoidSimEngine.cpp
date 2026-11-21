#include "boidsim.hpp"
#include <godot_cpp/classes/engine.hpp>

using namespace godot;

void BoidSim::_bind_methods() {}

void BoidSim::_physics_process(double delta) {
  if (Engine::get_singleton()->is_editor_hint())
    return;
  _tick(delta);
}
