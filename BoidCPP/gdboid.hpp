#pragma once

#include <godot_cpp/classes/sprite2d.hpp>

namespace godot {

class GDBoid : public Sprite2D {
  GDCLASS(GDBoid, Sprite2D)

private:
  double time_passed;

protected:
  static void _bind_methods();

public:
  GDBoid();
  ~GDBoid();

  void _process(double delta) override;
};

} // namespace godot
