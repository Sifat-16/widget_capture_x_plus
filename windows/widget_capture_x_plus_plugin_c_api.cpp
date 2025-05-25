#include "include/widget_capture_x_plus/widget_capture_x_plus_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "widget_capture_x_plus_plugin.h"

void WidgetCaptureXPlusPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  widget_capture_x_plus::WidgetCaptureXPlusPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
