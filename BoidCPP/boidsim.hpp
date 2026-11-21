#pragma once

#include <assert.h>
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector4_array.hpp>

namespace godot {

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
  float radius_separation = 1.0;

  float floor_height = 0;

  float height_target = 0.5;
};

class BoidSim : public Node {
  GDCLASS(BoidSim, Node)

private:
  using BoidID = uint16_t;
  static constexpr BoidID MAX_BOIDS = 2000;
  static constexpr BoidID BOID_NULL = -1;

  static constexpr float BOID_NEIGHBOR_RADIUS = 3.0;

  class FlockingSum {
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

      Vector3 get_position(Vector3 self) {
        return (position - self) / float(count);
      }
      Vector3 get_velocity(Vector3 self) {
        return (velocity - self) / float(count);
      }
    };

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
    void set_sums(BoidID boid_count, const PackedVector3Array &array_position,
                  const PackedVector3Array &array_velocity) {
      tick++;

      for (size_t i = 0; i < boid_count; i++) {
        const Vector3 &pos = array_position[i];
        const Vector3 &vel = array_velocity[i];
        Sum &sum = sums[get_cell_index(f2i(pos.x), f2i(pos.y), f2i(pos.z))];

        if (sum.tick != tick) {
          sum = Sum{tick};
        }

        sum.position += pos;
        sum.velocity += vel;

        sum.count++;
      }
    }

    Sum get_sum(Vector3 pos) {
      const int32_t x0 = f2i(pos.x - BOID_NEIGHBOR_RADIUS);
      const int32_t y0 = f2i(pos.y - BOID_NEIGHBOR_RADIUS);
      const int32_t z0 = f2i(pos.z - BOID_NEIGHBOR_RADIUS);

      Sum total;

      for (int32_t dy = 0; dy <= 1; dy++)
        for (int32_t dx = 0; dx <= 1; dx++)
          for (int32_t dz = 0; dz <= 1; dz++) {
            const Sum &s = sums[get_cell_index(x0 + dx, y0 + dy, z0 + dz)];

            if (s.tick != tick)
              continue;

            total.count += s.count;
            total.position += s.position;
            total.velocity += s.velocity;
          }

      return total;
    }
  };

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

    void unlink(BoidID id) {
      assert(id < MAX_BOIDS);
      BoidLink &link = links[id];

      if (link.prev < MAX_BOIDS)
        links[link.prev].next = link.next;

      if (link.next < MAX_BOIDS)
        links[link.next].prev = link.prev;

      if (link.cell_index != BoidLink::CELL_NULL) {
        BoidID &cell = table[link.cell_index];
        if (cell == id)
          cell = link.next;
      }

      link.next = BOID_NULL;
      link.prev = BOID_NULL;
      link.cell_index = BoidLink::CELL_NULL;
    }

    void insert(uint16_t boid, Vector3 pos) {
      assert(boid < MAX_BOIDS);

      CellIndex cell_index = get_cell_index(f2i(pos.x), f2i(pos.y), f2i(pos.z));

      BoidLink &link = links[boid];

      if (link.cell_index == cell_index)
        return;

      unlink(boid);
      BoidID &cell = table[cell_index];

      if (cell < MAX_BOIDS)
        links[cell].prev = boid;

      link.next = cell;
      link.cell_index = cell_index;
      cell = boid;
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

  NearbyLookup nearby_lookup;

public:
  BoidID boid_count = 0;
  PackedVector3Array array_boid_position;
  PackedVector4Array array_boid_rotation;
  PackedVector3Array array_boid_velocity;
  PackedInt32Array array_boid_health;
  PackedInt32Array array_boid_type;

public:
  TypedArray<BoidType> boid_types;

  void set_position(int boid, Vector3 pos) {
    if (boid >= boid_count || boid < 0)
      return;
    nearby_lookup.insert(boid, pos);
    array_boid_position[boid] = pos;
  }

  int add_boid(int type_index, Vector3 pos, Quaternion r, Vector3 velocity,
               int health) {

    if (boid_count >= MAX_BOIDS)
      return -1;

    if (type_index >= boid_types.size() || type_index < 0)
      return -1;

    BoidID boid = boid_count;
    boid_count++;

    set_position(boid, pos);
    array_boid_rotation[boid] = Vector4(r.x, r.y, r.z, r.w);
    array_boid_velocity[boid] = velocity;
    array_boid_health[boid] = health;
    array_boid_type[boid] = type_index;

    return boid;
  }

  void remove(int boid) {
    if (boid >= boid_count || boid < 0)
      return;

    BoidID last_boid = boid_count - 1;

    set_position(boid, array_boid_position[last_boid]);
    array_boid_rotation[boid] = array_boid_rotation[last_boid];
    array_boid_velocity[boid] = array_boid_velocity[last_boid];
    array_boid_health[boid] = array_boid_health[last_boid];
    array_boid_type[boid] = array_boid_type[last_boid];

    nearby_lookup.unlink(last_boid);

    boid_count = last_boid;
  }

  PackedInt32Array list(Vector3 pos);

protected:
  static void _bind_methods();

public:
  BoidSim() {
    array_boid_position.resize(MAX_BOIDS);
    array_boid_rotation.resize(MAX_BOIDS);
    array_boid_velocity.resize(MAX_BOIDS);
    array_boid_health.resize(MAX_BOIDS);
    array_boid_type.resize(MAX_BOIDS);
  }
  ~BoidSim();

  void _process(double delta) override;
};

} // namespace godot
