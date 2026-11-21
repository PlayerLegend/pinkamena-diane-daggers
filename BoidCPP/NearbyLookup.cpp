#include "boidsim.hpp"
using namespace godot;

void NearbyLookup::unlink(BoidID id) {
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

void NearbyLookup::insert(uint16_t boid, Vector3 pos) {
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
