#pragma once

#include <assert.h>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector4_array.hpp>
#include <vector>

namespace godot {
using BoidID = uint16_t;
static constexpr BoidID BOID_NULL = -1;
static constexpr BoidID MAX_BOIDS = 2000;
static constexpr float BOID_NEIGHBOR_RADIUS = 3.0;

class NearbyLookup {
  static constexpr size_t array_width = (1 << 6);
  static constexpr size_t array_height = (1 << 4);
  static constexpr float CELL_WIDTH = BOID_NEIGHBOR_RADIUS * 2.0;
  struct BoidLink {
    static constexpr uint32_t CELL_NULL = -1;
    BoidID prev = BOID_NULL;
    BoidID next = BOID_NULL;
    uint32_t cell_index = CELL_NULL;
  };
  std::array<BoidLink, MAX_BOIDS> links;
  std::array<BoidID, array_width * array_width * array_height> table;

  using CellIndex = uint32_t;

  static int32_t f2i(float f) { return (int32_t)std::floor(f / CELL_WIDTH); }

  static CellIndex get_cell_index(int32_t cx, int32_t cy, int32_t cz) {
    constexpr CellIndex mask_xz = array_width - 1;
    constexpr CellIndex mask_y = array_height - 1;
    CellIndex x = (CellIndex)cx & mask_xz;
    CellIndex y = (CellIndex)cy & mask_y;
    CellIndex z = (CellIndex)cz & mask_xz;
    return (y * array_width + x) * array_width + z;
  }

public:
  NearbyLookup() {
    for (BoidID &i : table)
      i = BOID_NULL;
  }

  void unlink(BoidID id);
  void insert(uint16_t boid, Vector3 pos);

  BoidID lookup_cell(Vector3 pos) {
    return table[get_cell_index(f2i(pos.x), f2i(pos.y), f2i(pos.z))];
  }

  std::array<BoidID, 8> lookup_area(Vector3 pos) {
    const int32_t x0 = f2i(pos.x - BOID_NEIGHBOR_RADIUS);
    const int32_t y0 = f2i(pos.y - BOID_NEIGHBOR_RADIUS);
    const int32_t z0 = f2i(pos.z - BOID_NEIGHBOR_RADIUS);

    std::array<BoidID, 8> heads;
    int n = 0;
    for (int32_t dy = 0; dy <= 1; dy++)
      for (int32_t dx = 0; dx <= 1; dx++)
        for (int32_t dz = 0; dz <= 1; dz++)
          heads[n++] = table[get_cell_index(x0 + dx, y0 + dy, z0 + dz)];
    return heads;
  }

  BoidID next(BoidID boid) {
    if (boid < MAX_BOIDS)
      return links[boid].next;
    return BOID_NULL;
  }
};

class BoidType : public Resource {
  GDCLASS(BoidType, Resource)

public:
  Ref<Mesh> mesh;
  Ref<Material> material_override;
  int health = 1;
  float max_speed = 16;
  float min_speed = 4.5;
  float max_force = 12;

  float weight_separation = 0.8;
  float weight_alignment = 0.1;
  float weight_cohesion = 0.2;
  float weight_bounds = 1.1;
  float weight_floor = 1.5;
  float weight_obstacles = 1.0;
  float weight_chase = 0.3;

  float radius_collision = 0.5;

  float floor_height = 0;

  float height_target = 0.5;

  float turn_rate = 0.5;

  static void _bind_methods();

#define BOID_PROP(T, N)                                                        \
  void set_##N(T v) { N = v; }                                                 \
  T get_##N() const { return N; }

  BOID_PROP(Ref<Mesh>, mesh)
  BOID_PROP(Ref<Material>, material_override)
  BOID_PROP(int, health)
  BOID_PROP(float, max_speed)
  BOID_PROP(float, min_speed)
  BOID_PROP(float, max_force)
  BOID_PROP(float, weight_separation)
  BOID_PROP(float, weight_alignment)
  BOID_PROP(float, weight_cohesion)
  BOID_PROP(float, weight_bounds)
  BOID_PROP(float, weight_floor)
  BOID_PROP(float, weight_obstacles)
  BOID_PROP(float, weight_chase)
  BOID_PROP(float, radius_collision)
  BOID_PROP(float, floor_height)
  BOID_PROP(float, height_target)
};

class FlockingSum {
  // spatial hash sums, does wrap

  static constexpr size_t array_width = (1 << 6);
  static constexpr size_t array_height = (1 << 4);
  static constexpr float CELL_WIDTH = BOID_NEIGHBOR_RADIUS * 2.0;
  using CellIndex = uint32_t;
  uint32_t tick = 0;

public:
  struct Sum {
    uint32_t tick = -1;
    BoidID count = 0;
    Vector3 position;
    Vector3 velocity;

    Vector3 get_position(Vector3 self) const {
      if (count < 2)
        return self;
      return (position - self) / float(count - 1);
    }
    Vector3 get_velocity(Vector3 self) const {
      if (count < 2)
        return Vector3{};
      return (velocity - self) / float(count - 1);
    }
  };

  void set_sums(BoidID boid_count, const PackedVector3Array &array_position,
                const PackedVector3Array &array_velocity);

  Sum get_sum(Vector3 pos);

private:
  std::array<Sum, array_width * array_width * array_height> sums;

  static int32_t f2i(float f) { return (int32_t)std::floor(f / CELL_WIDTH); }

  static CellIndex get_cell_index(int32_t cx, int32_t cy, int32_t cz) {
    constexpr CellIndex mask_xz = array_width - 1;
    constexpr CellIndex mask_y = array_height - 1;
    CellIndex x = (CellIndex)cx & mask_xz;
    CellIndex y = (CellIndex)cy & mask_y;
    CellIndex z = (CellIndex)cz & mask_xz;
    return (y * array_width + x) * array_width + z;
  }

public:
};

class BoidArrays {
  BoidID boid_count = 0;
  NearbyLookup &nearby_lookup;

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
  BoidArrays(NearbyLookup &l);
};

class BoidMMI : public Node {
  static constexpr int TRANSFORM_FLOATS = 12;
  std ::vector<Ref<MultiMesh>> multimeshes;
  PackedFloat32Array transforms;
  int current_type = -1;
  int current_transform = 0;
  float *p_transform = nullptr;
  GDCLASS(BoidMMI, Node);

protected:
  static void _bind_methods() {}

public:
  void set_types(TypedArray<BoidType> boid_types);

  void start_type(uint16_t type_index);
  void set_transform(Transform3D transform);
  void finish_type(uint16_t type_index);
};

class BoidSim : public Node {
  GDCLASS(BoidSim, Node)

  float BOID_SEPARATION = 1.0;
  float BOID_SEPARATION_SQUARED = BOID_SEPARATION * BOID_SEPARATION;

private:
  NearbyLookup nearby_lookup;
  FlockingSum flocking_sum;
  BoidArrays boid_arrays;

private:
  uint32_t tick = 0;

public:
  int add_boid(int type_index, Vector3 pos, Quaternion r, Vector3 velocity,
               int health);

  void remove(int boid);

  int raycast(Vector3 origin, Vector3 direction);

protected:
  static void _bind_methods();

private:
  BoidMMI *boid_mmi = nullptr;
  TypedArray<BoidType> types;

public:
  void set_types(TypedArray<BoidType> t);
  TypedArray<BoidType> get_types() const { return types; }

private:
  Vector3 _get_separation(BoidArrays::Pointers &p, BoidID boid,
                          const BoidType *type);
  Vector3 _get_alignment(BoidArrays::Pointers &p, BoidID boid,
                         const BoidType *type, const FlockingSum::Sum &sum);
  Vector3 _get_cohesion(BoidArrays::Pointers &p, BoidID boid,
                        const BoidType *type, const FlockingSum::Sum &sum);

  Vector3 _get_boid_pass_steering(BoidArrays::Pointers &p, BoidID boid,
                                  const BoidType *type);
  Vector3 _get_chase_steering(BoidArrays::Pointers &p, BoidID boid,
                              const BoidType *type,
                              const TypedArray<Node> &targets);

  void _compute_steering(BoidArrays::Pointers &p);

  void _compute_transforms(BoidArrays::Pointers &p, double delta);
  void _tick(double delta);

public:
  BoidSim();
  ~BoidSim();

  void _physics_process(double delta) override;
};

} // namespace godot
