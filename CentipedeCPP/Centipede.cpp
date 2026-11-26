#include "Centipede.hpp"
#include <algorithm>

#include <godot_cpp/classes/engine.hpp>

using namespace godot;

void Centipede::_ready() {

  if (Engine::get_singleton()->is_editor_hint())
    return;

  if (!(segment_spacing > 0.0) || !std::isfinite(segment_spacing)) {
    ERR_PRINT("Centipede: segment_spacing must be > 0 and finite.");
    set_process_mode(PROCESS_MODE_DISABLED);
    return;
  }

  set_as_top_level(true);
  setup_arrays();
  setup_multiplayer();
}

Transform3D Centipede::PathTarget::lerp(const PathTarget &other,
                                        double fac) const {
  Vector3 pos = position.lerp(other.position, fac);
  Quaternion rot = rotation.slerp(other.rotation, fac);
  return Transform3D(Basis(rot), pos);
}

void Centipede::setup_arrays() {
  size_t count = 0;

  for (auto child_node : get_children()) {
    Node3D *child = Object::cast_to<Node3D>(child_node);
    if (!child)
      continue;

    child->set_as_top_level(true);
    count++;
  }

  targets.initialize(count + 1 + RECENT_WINDOW,
                     PathTarget{get_position(), get_quaternion()});
}

void Centipede::send_recent(size_t n) {
  if (!targets.size())
    return;

  n = std::min(n, targets.size());

  recent_positions.resize(n);
  recent_rotations.resize(n);

  Vector3 *pos = recent_positions.ptrw();
  Vector4 *rot = recent_rotations.ptrw();

  for (size_t i = 0; i < n; i++) {
    const PathTarget &t = targets[head_index + i];
    pos[i] = t.position;
    rot[i] = Vector4(t.rotation.x, t.rotation.y, t.rotation.z, t.rotation.w);
  }
}

void Centipede::receive_recent() {
  if (!targets.size())
    return;

  if (recent_positions.size() != recent_rotations.size()) {
    godot::UtilityFunctions::push_warning(
        "Centipede recent_* arrays size mismatch");
  }

  size_t n = std::min({(size_t)recent_positions.size(),
                       (size_t)recent_rotations.size(), targets.size()});

  const Vector3 *pos = recent_positions.ptr();
  const Vector4 *rot = recent_rotations.ptr();

  for (size_t i = 0; i < n; i++) {
    PathTarget &t = targets[head_index + i];
    const Vector4 &r = rot[i];
    t.position = pos[i];
    t.rotation = Quaternion(r.x, r.y, r.z, r.w).normalized();
  }
}

void Centipede::setup_multiplayer() {
  TypedArray<String> sync_props = {
      ":global_transform",
      ":head_index",
      ":recent_positions",
      ":recent_rotations",
  };

  // Build this BEFORE adding the netfox nodes, so they aren't in the list.
  TypedArray<String> interp_props = {":global_transform"};

  TypedArray<Node> children = get_children();
  for (int i = 0; i < children.size(); i++) {
    Node3D *child = Object::cast_to<Node3D>(children[i]);
    if (child) {
      interp_props.push_back(String(get_path_to(child)) + ":global_transform");
    }
  }

  Node *rollback_synchronizer =
      instantiate_global_class("RollbackSynchronizer");
  ERR_FAIL_NULL(rollback_synchronizer);
  rollback_synchronizer->set("state_properties", sync_props);
  rollback_synchronizer->set("root", this);

  Node *tick_interpolator = instantiate_global_class("TickInterpolator");
  if (tick_interpolator == nullptr) {
    memdelete(rollback_synchronizer);
    return;
  }
  tick_interpolator->set("properties", interp_props);
  tick_interpolator->set("root", this);

  add_child(rollback_synchronizer);
  add_child(tick_interpolator);

  rollback_synchronizer->call("process_settings");
}

void Centipede::advance_targets() {
  Vector3 last = targets[head_index].position;
  Vector3 position = get_position();
  Vector3 to_head = position - last;
  double dist = to_head.length();
  Quaternion quaternion = get_quaternion();

  head_advance_count = 0;

  while (dist >= segment_spacing) {
    last += (to_head / dist) * segment_spacing;
    head_index = targets.advance_index(head_index);
    PathTarget &target = targets[head_index];
    target.position = last;
    target.rotation = quaternion;
    to_head = position - last;
    dist = to_head.length();
    head_advance_count++;
  }
}

void Centipede::advance_children() {
  double head_distance =
      (targets[head_index].position - get_position()).length();

  double fac = head_distance / segment_spacing;

  size_t i = 0;

  for (auto child_node : get_children()) {

    Node3D *child = Object::cast_to<Node3D>(child_node);
    if (!child)
      continue;

    size_t prev = i + head_index;
    size_t next = prev + 1;
    child->set_global_transform(targets[next].lerp(targets[prev], fac));
    i++;
  }
}

void Centipede::_rollback_tick(double, int64_t, bool p_is_fresh) {

  if (segment_spacing <= 0 || std::isnan(segment_spacing)) {

    godot::UtilityFunctions::push_warning(
        "Invalid segment_spacing on Centipede");
    queue_free();
    return;
  }

  if (Engine::get_singleton()->is_editor_hint() || targets.size() == 0)
    return;

  // netfox has already restored state properties; mirror them into the ring.
  receive_recent();

  // Authority records; so does anyone resimulating. Fresh ticks on other
  // peers build the body purely from synced state and must not touch _recent_*.
  if (is_multiplayer_authority() || !p_is_fresh) {
    advance_targets();
    send_recent(std::max<int>(head_advance_count, RECENT_WINDOW));
  }

  advance_children();
}

void Centipede::_bind_methods() {
  ClassDB::bind_method(D_METHOD("_rollback_tick", "delta", "tick", "is_fresh"),
                       &Centipede::_rollback_tick);

  ClassDB::bind_method(D_METHOD("set_recent_positions", "v"),
                       &Centipede::set_recent_positions);
  ClassDB::bind_method(D_METHOD("get_recent_positions"),
                       &Centipede::get_recent_positions);
  ClassDB::bind_method(D_METHOD("set_recent_rotations", "v"),
                       &Centipede::set_recent_rotations);
  ClassDB::bind_method(D_METHOD("get_recent_rotations"),
                       &Centipede::get_recent_rotations);
  ClassDB::bind_method(D_METHOD("set_head_index", "v"),
                       &Centipede::set_head_index);
  ClassDB::bind_method(D_METHOD("get_head_index"), &Centipede::get_head_index);
  ClassDB::bind_method(D_METHOD("set_segment_spacing", "v"),
                       &Centipede::set_segment_spacing);
  ClassDB::bind_method(D_METHOD("get_segment_spacing"),
                       &Centipede::get_segment_spacing);
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "segment_spacing"),
               "set_segment_spacing", "get_segment_spacing");

  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR3_ARRAY, "recent_positions"),
               "set_recent_positions", "get_recent_positions");
  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR4_ARRAY, "recent_rotations"),
               "set_recent_rotations", "get_recent_rotations");
  ADD_PROPERTY(PropertyInfo(Variant::INT, "head_index"), "set_head_index",
               "get_head_index");
}

Node *Centipede::instantiate_global_class(const StringName &name) {
  TypedArray<Dictionary> list =
      ProjectSettings::get_singleton()->get_global_class_list();
  for (int i = 0; i < list.size(); i++) {
    Dictionary d = list[i];
    if (StringName(d["class"]) == name) {
      Ref<Script> s = ResourceLoader::get_singleton()->load(d["path"]);
      if (s.is_null())
        return nullptr;
      Variant v = s->call("new");
      return Object::cast_to<Node>(v.operator Object *());
    }
  }
  return nullptr;
}
