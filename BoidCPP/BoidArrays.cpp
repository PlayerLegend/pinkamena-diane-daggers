#include "BoidArrays.hpp"
#include <godot_cpp/core/error_macros.hpp>

using namespace godot;

Ref<BoidState> BoidArrays::get_state(BoidID boid) {
  Ref<BoidState> result = memnew(BoidState);
  int type_index = type_of(boid);
  if (type_index < 0)
    return nullptr;

  BoidType *type = Object::cast_to<BoidType>(boid_types[type_index]);
  if (!type)
    return nullptr;

  Pointers p(*this);

  result->type = type;
  result->health = p.health[boid];
  result->position = p.pos[boid];
  result->velocity = p.vel[boid];
  result->rotation = p.get_rot(boid);

  return result;
}

void BoidArrays::_move_boid(Pointers &p, int from, int to) {
  if (from == to)
    return;

  p.rot[to] = p.rot[from];
  p.vel[to] = p.vel[from];
  p.health[to] = p.health[from];
  p.steer[to] = p.steer[from];

  nearby_lookup.unlink(to);
  p.set_pos(to, p.pos[from]);

  nearby_lookup.unlink(from);
}

BoidID BoidArrays::_new_boid_index(Pointers &p, int type_index) {
  const int type_count = (int)type_end.size();
  if (type_index < 0 || type_index >= type_count || boid_count >= MAX_BOIDS)
    return BOID_NULL;

  int *ends = type_end.ptrw();

  boid_count++;

  for (int t = type_count - 1; t > type_index; t--) {
    const int first = ends[t - 1]; // first boid of type t
    const int past_last = ends[t]; // one past its last

    // For a non-empty section, move its first boid to the end, which frees
    // the slot at `first` for the previous type to grow into. An empty
    // section needs no move, only a shift.
    if (first != past_last)
      _move_boid(p, first, past_last);

    ends[t]++;
  }

  // The slot at the old end of our section is now free.
  return ends[type_index]++;
}

BoidID BoidArrays::add_boid(int type_index, Vector3 pos, Quaternion r,
                            Vector3 velocity, int health) {
  if (boid_count >= MAX_BOIDS)
    return -1;

  if (type_index >= boid_types.size() || type_index < 0)
    return -1;

  Pointers p(*this);

  BoidID boid = _new_boid_index(p, type_index);

  if (boid >= MAX_BOIDS)
    return -1;

  p.set_pos(boid, pos);
  p.rot[boid] = Vector4(r.x, r.y, r.z, r.w);
  p.vel[boid] = velocity;
  p.health[boid] = health;
  p.steer[boid] = Vector3{};

  return boid;
}

int BoidArrays::type_of(BoidID boid) const {
  if (boid >= boid_count)
    return -1;

  for (int i = 0; i < type_count; i++) {
    if (boid < type_end[i])
      return i;
  }

  return -1;
}

void BoidArrays::remove_boid(BoidID boid) {
  const int type = type_of(boid);
  if (type < 0)
    return;

  const int type_count = (int)type_end.size();
  int *ends = type_end.ptrw();

  Pointers p(*this);
  _move_boid(p, ends[type] - 1, boid);
  ends[type]--;

  for (int u = type + 1; u < type_count; u++) {
    const int hole = ends[u - 1];
    const int last = ends[u] - 1;

    if (last > hole)
      _move_boid(p, last, hole);

    ends[u]--;
  }

  boid_count--;
  nearby_lookup.unlink(boid_count);

  UtilityFunctions::print("Removed boid ", boid);
}

void BoidArrays::set_types(TypedArray<BoidType> types) {
  if (boid_count != 0) {
    UtilityFunctions::push_warning("Second use of set_types ignored");
    return;
  }

  boid_types = types;

  type_count = types.size();
  type_end.resize(type_count);
  type_iter.resize(type_count);
  type_end.fill(0);
  type_iter.fill(0);
}

BoidArrays::BoidArrays() {
  array_position.resize(MAX_BOIDS);
  array_rotation.resize(MAX_BOIDS);
  array_velocity.resize(MAX_BOIDS);
  array_health.resize(MAX_BOIDS);
  array_steering_flock.resize(MAX_BOIDS);
}

BoidArrays::Region::Region(BoidArrays &a, size_t index)
    : type_index(index), iter(a.type_iter[index]) {

  type = Object::cast_to<BoidType>(a.boid_types[index]);

  begin = (index > 0) ? a.type_end[index - 1] : 0;
  end = a.type_end[index];
  count = end - begin;
}

BoidArrays::Pointers::Pointers(BoidArrays &a)
    : pos_w(a.array_position.ptrw()), nearby_lookup(&a.nearby_lookup),
      pos(a.array_position.ptr()), rot(a.array_rotation.ptrw()),
      vel(a.array_velocity.ptrw()), health(a.array_health.ptrw()),
      steer(a.array_steering_flock.ptrw()) {}

void BoidArrays::_bind_methods() {
  ClassDB::bind_method(D_METHOD("type_of", "boid"), &BoidArrays::type_of);

  ClassDB::bind_method(D_METHOD("set_types", "types"), &BoidArrays::set_types);
  ClassDB::bind_method(D_METHOD("get_boid_types"), &BoidArrays::get_boid_types);
  ClassDB::bind_method(D_METHOD("add_boid", "type_index", "pos", "rotation",
                                "velocity", "health"),
                       &BoidArrays::add_boid);
  ClassDB::bind_method(D_METHOD("remove_boid", "boid"),
                       &BoidArrays::remove_boid);

  ClassDB::bind_method(D_METHOD("get_boid_count"), &BoidArrays::get_boid_count);
  ClassDB::bind_method(D_METHOD("get_type_count"), &BoidArrays::get_type_count);

  ClassDB::bind_method(D_METHOD("get_array_position"),
                       &BoidArrays::get_array_position);
  ClassDB::bind_method(D_METHOD("get_array_rotation"),
                       &BoidArrays::get_array_rotation);
  ClassDB::bind_method(D_METHOD("get_array_velocity"),
                       &BoidArrays::get_array_velocity);
  ClassDB::bind_method(D_METHOD("get_array_health"),
                       &BoidArrays::get_array_health);
  ClassDB::bind_method(D_METHOD("get_array_steering_flock"),
                       &BoidArrays::get_array_steering_flock);

  ClassDB::bind_method(D_METHOD("get_type_end"), &BoidArrays::get_type_end);
  ClassDB::bind_method(D_METHOD("get_type_iter"), &BoidArrays::get_type_iter);

  ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "boid_types",
                            PROPERTY_HINT_TYPE_STRING,
                            String::num_int64(Variant::OBJECT) + "/" +
                                String::num_int64(PROPERTY_HINT_RESOURCE_TYPE) +
                                ":BoidType"),
               "set_types", "get_boid_types");

  ADD_PROPERTY(PropertyInfo(Variant::INT, "boid_count", PROPERTY_HINT_NONE, "",
                            PROPERTY_USAGE_EDITOR),
               "", "get_boid_count");

  ADD_PROPERTY(PropertyInfo(Variant::INT, "type_count", PROPERTY_HINT_NONE, "",
                            PROPERTY_USAGE_EDITOR),
               "", "get_type_count");

  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR3_ARRAY, "array_position",
                            PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR),
               "", "get_array_position");

  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR4_ARRAY, "array_rotation",
                            PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR),
               "", "get_array_rotation");

  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR3_ARRAY, "array_velocity",
                            PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR),
               "", "get_array_velocity");

  ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY, "array_health",
                            PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR),
               "", "get_array_health");

  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR3_ARRAY,
                            "array_steering_flock", PROPERTY_HINT_NONE, "",
                            PROPERTY_USAGE_EDITOR),
               "", "get_array_steering_flock");

  ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY, "type_end",
                            PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR),
               "", "get_type_end");

  ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY, "type_iter",
                            PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR),
               "", "get_type_iter");
}
