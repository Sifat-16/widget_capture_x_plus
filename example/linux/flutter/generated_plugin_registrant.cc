//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <widget_capture_x_plus/widget_capture_x_plus_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) widget_capture_x_plus_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WidgetCaptureXPlusPlugin");
  widget_capture_x_plus_plugin_register_with_registrar(widget_capture_x_plus_registrar);
}
