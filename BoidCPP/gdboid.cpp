#include "gdboid.hpp"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void GDBoid::_bind_methods() {}

GDBoid::GDBoid() {
  // Initialize any variables here.
  time_passed = 0.0;
}

GDBoid::~GDBoid() {
  // Add your cleanup here.
}

void GDBoid::_process(double delta) {
  time_passed += delta;

  Vector2 new_position = Vector2(10.0 + (10.0 * sin(time_passed * 2.0)),
                                 10.0 + (10.0 * cos(time_passed * 1.5)));

  set_position(new_position);
}
