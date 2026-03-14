#include "include/pdf_renderer_bridge/pdf_renderer_bridge_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "pdf_renderer_bridge_plugin.h"

void PdfRendererBridgePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  pdf_renderer_bridge::PdfRendererBridgePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
