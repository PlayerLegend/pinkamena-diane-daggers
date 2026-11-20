#pragma once

#include <assert.h>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector4_array.hpp>

namespace godot {

class BoidSim : public Node {
  GDCLASS(BoidSim, Node)

private:
  using BoidID = uint16_t;
  static constexpr BoidID MAX_BOIDS = 2000;
  static constexpr BoidID BOID_NULL = -1;

  static constexpr float BOID_NEIGHBOR_RADIUS = 3.0;

  class SpatialHash {
    static constexpr size_t array_size = (1 << 6);
    static constexpr float CELL_WIDTH = BOID_NEIGHBOR_RADIUS * 2.0;
    struct BoidLink {
      static constexpr uint32_t CELL_NULL = -1;
      BoidID prev = -1;
      BoidID next = -1;
      uint32_t cell_index = CELL_NULL;
    };
    std::array<BoidLink, MAX_BOIDS> links;
    std::array<BoidID, array_size * array_size * array_size> table;

    using CellIndex = uint32_t;

    static int32_t f2i(float f) { return (int32_t)std::floor(f / CELL_WIDTH); }

    static CellIndex getCellIndex(Vector3 pos) {
      constexpr CellIndex mask = array_size - 1;
      // two's complement wrap handles negatives
      CellIndex x = (CellIndex)f2i(pos.x) & mask;
      CellIndex y = (CellIndex)f2i(pos.y) & mask;
      CellIndex z = (CellIndex)f2i(pos.z) & mask;
      return (x * array_size + y) * array_size + z;
    }

  public:
    SpatialHash() {
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

      CellIndex cell_index = getCellIndex(pos);

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

    BoidID lookup(Vector3 pos) { return table[getCellIndex(pos)]; }

    BoidID next(BoidID boid) {
      if (boid < MAX_BOIDS)
        return links[boid].next;
      return BOID_NULL;
    }
  };

  SpatialHash spatial_hash;

public:
  BoidID boid_count = 0;
  PackedVector3Array boid_position;
  PackedVector4Array boid_rotation;
  PackedVector3Array boid_velocity;
  PackedInt32Array boid_health;

private:
  void resize_arrays(size_t n) {
    boid_position.resize(n);
    boid_rotation.resize(n);
    boid_velocity.resize(n);
    boid_health.resize(n);
  }

public:
  void set_position(int boid, Vector3 pos) {
    if (boid >= boid_count || boid < 0)
      return;
    spatial_hash.insert(boid, pos);
    boid_position[boid] = pos;
  }

  int add_boid(Vector3 pos, Quaternion r, Vector3 velocity, int health) {

    if (boid_count >= MAX_BOIDS)
      return -1;

    BoidID boid = boid_count;
    boid_count++;

    resize_arrays(boid_count);

    set_position(boid, pos);
    boid_rotation[boid] = Vector4(r.x, r.y, r.z, r.w);
    boid_velocity[boid] = velocity;
    boid_health[boid] = health;

    return boid;
  }

  void remove(int boid) {
    if (boid >= boid_count || boid < 0)
      return;

    BoidID last_boid = boid_count - 1;

    set_position(boid, boid_position[last_boid]);
    boid_rotation[boid] = boid_rotation[last_boid];
    boid_velocity[boid] = boid_velocity[last_boid];
    boid_health[boid] = boid_health[last_boid];

    spatial_hash.unlink(last_boid);

    boid_count = last_boid;

    resize_arrays(boid_count);
  }

  PackedInt32Array list(Vector3 pos);

protected:
  static void _bind_methods();

public:
  BoidSim();
  ~BoidSim();

  void _process(double delta) override;
};

} // namespace godot
