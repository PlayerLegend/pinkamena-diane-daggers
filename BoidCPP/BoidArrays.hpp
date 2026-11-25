#pragma once

#include "BoidDefs.hpp"
#include "BoidType.hpp"
#include "FlockingSum.hpp"
#include "NearbyLookup.hpp"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector4_array.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4.hpp>

namespace godot {
class BoidArrays : public Node {
  GDCLASS(BoidArrays, Node)

  BoidID boid_count = 0;
  NearbyLookup nearby_lookup;

public:
  BoidID get_boid_count() const { return boid_count; }
  size_t get_type_count() const { return type_count; }

  PackedVector3Array get_array_position() const { return array_position; }
  PackedVector4Array get_array_rotation() const { return array_rotation; }
  PackedVector3Array get_array_velocity() const { return array_velocity; }
  PackedInt32Array get_array_health() const { return array_health; }
  PackedVector3Array get_array_steering_flock() const {
    return array_steering_flock;
  }

  TypedArray<BoidType> get_boid_types() const { return boid_types; }

  PackedInt32Array get_type_end() const { return type_end; }
  PackedInt32Array get_type_iter() const { return type_iter; }

protected:
  static void _bind_methods();

public:
  PackedVector3Array array_position;
  PackedVector4Array array_rotation;
  PackedVector3Array array_velocity;
  PackedInt32Array array_health;
  PackedVector3Array array_steering_flock;

  TypedArray<BoidType> boid_types;

  PackedInt32Array type_end; // last index of a type + 1
  PackedInt32Array type_iter;

  size_t type_count = 0;

public:
  class Pointers;

private:
  BoidID _new_boid_index(Pointers &p, int type_index);
  void _move_boid(Pointers &p, int from, int to);

public:
  NearbyLookup &get_nearby_lookup() { return nearby_lookup; }
  int type_of(BoidID boid) const;

  void set_types(TypedArray<BoidType> boid_types);

  BoidID add_boid(int type_index, Vector3 pos, Quaternion r, Vector3 velocity,
                  int health);

  void remove_boid(BoidID boid);

  void set_flocking_sums(FlockingSum &f) {
    f.set_sums(boid_count, array_position, array_velocity);
  }

  class Pointers {
    friend BoidArrays;

    Vector3 *pos_w = nullptr;
    NearbyLookup *nearby_lookup = nullptr;

  public:
    const Vector3 *pos = nullptr;
    Vector4 *rot = nullptr;
    Vector3 *vel = nullptr;
    int *health = nullptr;
    Vector3 *steer = nullptr;

    Quaternion get_rot(BoidID boid) const {
      const Vector4 &r = rot[boid];
      return Quaternion(r.x, r.y, r.z, r.w);
    }

    void set_rot(BoidID boid, Quaternion r) {
      rot[boid] = Vector4(r.x, r.y, r.z, r.w);
    }

    void set_pos(BoidID boid, Vector3 pos) {
      nearby_lookup->insert(boid, pos);
      pos_w[boid] = pos;
    }

    Pointers(BoidArrays &);
  };

  class Region {
    friend BoidArrays;
    int &iter;

  public:
    int type_index;
    const BoidType *type;
    size_t begin;
    size_t end;
    size_t count;

    size_t get_boid() { return begin + (uint32_t)(iter++) % count; }

    Region(BoidArrays &, size_t type_index);
  };

public:
  BoidArrays();
};
} // namespace godot
