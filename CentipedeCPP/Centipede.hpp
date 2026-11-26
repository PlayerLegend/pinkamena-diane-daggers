#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <vector>

namespace godot {
class Centipede : public Node3D {
  GDCLASS(Centipede, Node3D)

  static constexpr int RECENT_WINDOW = 4;

  struct PathTarget {
    Vector3 position = Vector3{};
    Quaternion rotation = Quaternion{0, 0, 0, 1};
    Transform3D lerp(const PathTarget &other, double fac) const;
  };

  class TargetRing {
    std::vector<PathTarget> data;

  public:
    void initialize(size_t n, const PathTarget &fill) { data.assign(n, fill); }
    size_t size() const { return data.size(); }
    size_t wrap(int64_t n) const {
      const int64_t s = (int64_t)data.size();
      return ((n % s) + s) % s;
    }

    PathTarget &operator[](int64_t n) { return data[wrap(n)]; }
    int64_t advance_index(int64_t n) { return wrap(n - 1); }
  };

  PackedVector3Array recent_positions;
  PackedVector4Array recent_rotations;

  void send_recent(size_t);
  void receive_recent();

  TargetRing targets;

  double segment_spacing = 1.0;
  int head_advance_count = 0;

  Node *instantiate_global_class(const StringName &p_class_name);
  void setup_multiplayer();
  void advance_targets();
  void advance_children();
  void setup_arrays();

public:
  int head_index = 0;
  void _rollback_tick(double delta, int64_t tick, bool is_fresh);

public:
  void set_recent_positions(const PackedVector3Array &v) {
    recent_positions = v;
  }
  PackedVector3Array get_recent_positions() const { return recent_positions; }
  void set_recent_rotations(const PackedVector4Array &v) {
    recent_rotations = v;
  }
  PackedVector4Array get_recent_rotations() const { return recent_rotations; }
  void set_head_index(int v) { head_index = v; }
  int get_head_index() const { return head_index; }

  void set_segment_spacing(double v) {
    if (!(v > 0.0) || !std::isfinite(v)) {
      ERR_PRINT("Centipede: segment_spacing must be > 0 and finite.");
      return;
    }
    segment_spacing = v;
  }

  double get_segment_spacing() const { return segment_spacing; }

  void _ready() override;

protected:
  static void _bind_methods();
};

} // namespace godot
