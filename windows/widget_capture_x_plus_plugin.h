#ifndef FLUTTER_PLUGIN_WIDGET_CAPTURE_X_PLUS_PLUGIN_H_
#define FLUTTER_PLUGIN_WIDGET_CAPTURE_X_PLUS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace widget_capture_x_plus {

class WidgetCaptureXPlusPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WidgetCaptureXPlusPlugin();

  virtual ~WidgetCaptureXPlusPlugin();

  // Disallow copy and assign.
  WidgetCaptureXPlusPlugin(const WidgetCaptureXPlusPlugin&) = delete;
  WidgetCaptureXPlusPlugin& operator=(const WidgetCaptureXPlusPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace widget_capture_x_plus

#endif  // FLUTTER_PLUGIN_WIDGET_CAPTURE_X_PLUS_PLUGIN_H_
