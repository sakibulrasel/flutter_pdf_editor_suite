#ifndef FLUTTER_PLUGIN_PDF_RENDERER_BRIDGE_PLUGIN_H_
#define FLUTTER_PLUGIN_PDF_RENDERER_BRIDGE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace pdf_renderer_bridge {

class PdfRendererBridgePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  PdfRendererBridgePlugin();

  virtual ~PdfRendererBridgePlugin();

  // Disallow copy and assign.
  PdfRendererBridgePlugin(const PdfRendererBridgePlugin&) = delete;
  PdfRendererBridgePlugin& operator=(const PdfRendererBridgePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace pdf_renderer_bridge

#endif  // FLUTTER_PLUGIN_PDF_RENDERER_BRIDGE_PLUGIN_H_
