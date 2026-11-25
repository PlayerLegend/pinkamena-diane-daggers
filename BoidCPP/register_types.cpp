#include "register_types.hpp"

#include "boid.hpp"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_boidsim(ModuleInitializationLevel p_level) {
  if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }

  GDREGISTER_CLASS(BoidType);
  GDREGISTER_CLASS(BoidSim);
  GDREGISTER_CLASS(BoidMMI);
  GDREGISTER_CLASS(BoidArrays);
}

void uninitialize_boidsim(ModuleInitializationLevel p_level) {
  if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }
}

extern "C" {
GDExtensionBool GDE_EXPORT
boidsim_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
             const GDExtensionClassLibraryPtr p_library,
             GDExtensionInitialization *r_initialization) {
  godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library,
                                                 r_initialization);

  init_obj.register_initializer(initialize_boidsim);
  init_obj.register_terminator(uninitialize_boidsim);
  init_obj.set_minimum_library_initialization_level(
      MODULE_INITIALIZATION_LEVEL_SCENE);

  return init_obj.init();
}
}
