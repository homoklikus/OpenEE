// OpenEE – rejestracja klas GDExtension (etap 28).
#include <gdextension_interface.h>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "openee_symulacja.hpp"

using namespace godot;

namespace {
void inicjalizuj(ModuleInitializationLevel poziom) {
    if (poziom != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    GDREGISTER_CLASS(OpenEESymulacja);
}
void zakoncz(ModuleInitializationLevel poziom) { (void)poziom; }
}  // namespace

extern "C" GDExtensionBool GDE_EXPORT openee_gdextension_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
                                                              GDExtensionClassLibraryPtr p_library,
                                                              GDExtensionInitialization* r_initialization) {
    GDExtensionBinding::InitObject init(p_get_proc_address, p_library, r_initialization);
    init.register_initializer(inicjalizuj);
    init.register_terminator(zakoncz);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
