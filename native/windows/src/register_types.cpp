#include "register_types.h"

#include "windows_window_enumerator.h"

#include <godot_cpp/godot.hpp>

void initialize_little_chihiro_windows_module(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(WindowsWindowEnumerator);
}

void uninitialize_little_chihiro_windows_module(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	// Join the WinEventHook worker before its std::thread state is destroyed.
	stop_window_event_hook_global();
}

extern "C" {

GDExtensionBool GDE_EXPORT little_chihiro_windows_library_init(
		GDExtensionInterfaceGetProcAddress get_proc_address,
		GDExtensionClassLibraryPtr library,
		GDExtensionInitialization *initialization) {
	godot::GDExtensionBinding::InitObject init_object(get_proc_address, library, initialization);
	init_object.register_initializer(initialize_little_chihiro_windows_module);
	init_object.register_terminator(uninitialize_little_chihiro_windows_module);
	init_object.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_object.init();
}
}
