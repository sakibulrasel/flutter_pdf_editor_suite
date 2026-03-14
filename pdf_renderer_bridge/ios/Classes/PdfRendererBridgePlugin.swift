import Flutter
import PDFKit
import UIKit

public class PdfRendererBridgePlugin: NSObject, FlutterPlugin {
  private var nextDocumentId: Int = 1
  private var documents: [Int: OpenDocument] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "pdf_renderer_bridge",
      binaryMessenger: registrar.messenger()
    )
    let instance = PdfRendererBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "openDocument":
        try openDocument(call, result: result)
      case "getPageInfo":
        try getPageInfo(call, result: result)
      case "renderPage":
        try renderPage(call, result: result)
      case "closeDocument":
        try closeDocument(call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(
        FlutterError(
          code: "pdf_renderer_error",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func openDocument(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try requireArguments(call)
    let sourceType = try requireString(arguments, key: "sourceType")

    let fileUrl: URL
    let tempFileUrl: URL?

    switch sourceType {
    case "file":
      let path = try requireString(arguments, key: "path")
      fileUrl = URL(fileURLWithPath: path)
      tempFileUrl = nil
    case "bytes":
      let bytes = try requireBytes(arguments, key: "bytes")
      let temporaryUrl = FileManager.default.temporaryDirectory
        .appendingPathComponent("pdf_renderer_bridge_\(UUID().uuidString).pdf")
      try bytes.write(to: temporaryUrl, options: .atomic)
      fileUrl = temporaryUrl
      tempFileUrl = temporaryUrl
    default:
      throw PdfRendererError.unsupportedSourceType(sourceType)
    }

    guard FileManager.default.fileExists(atPath: fileUrl.path) else {
      throw PdfRendererError.fileNotFound(fileUrl.path)
    }

    guard let document = PDFDocument(url: fileUrl) else {
      if let tempFileUrl {
        try? FileManager.default.removeItem(at: tempFileUrl)
      }
      throw PdfRendererError.documentOpenFailed
    }

    let documentId = nextDocumentId
    nextDocumentId += 1
    documents[documentId] = OpenDocument(document: document, tempFileUrl: tempFileUrl)

    result([
      "documentId": documentId,
      "pageCount": document.pageCount,
    ])
  }

  private func getPageInfo(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try requireArguments(call)
    let documentId = try requireInt(arguments, key: "documentId")
    let pageIndex = try requireInt(arguments, key: "pageIndex")
    let page = try requirePage(documentId: documentId, pageIndex: pageIndex)
    let bounds = page.bounds(for: .mediaBox)

    result([
      "documentId": documentId,
      "pageIndex": pageIndex,
      "width": bounds.width,
      "height": bounds.height,
    ])
  }

  private func renderPage(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try requireArguments(call)
    let documentId = try requireInt(arguments, key: "documentId")
    let pageIndex = try requireInt(arguments, key: "pageIndex")
    let scale = try requireDouble(arguments, key: "scale")
    let backgroundColor = Int(truncating: (arguments["backgroundColor"] as? NSNumber) ?? 0xFFFFFFFF)
    let page = try requirePage(documentId: documentId, pageIndex: pageIndex)

    guard scale > 0 else {
      throw PdfRendererError.invalidArgument("scale must be greater than zero.")
    }

    let pageBounds = page.bounds(for: .mediaBox)
    let width = max(Int((pageBounds.width * scale).rounded(.up)), 1)
    let height = max(Int((pageBounds.height * scale).rounded(.up)), 1)

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
    let image = renderer.image { context in
      let cgContext = context.cgContext
      cgContext.setFillColor(uiColorFromArgb(backgroundColor).cgColor)
      cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))

      cgContext.saveGState()
      cgContext.translateBy(x: 0, y: CGFloat(height))
      cgContext.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
      page.draw(with: .mediaBox, to: cgContext)
      cgContext.restoreGState()
    }

    guard let pngData = image.pngData() else {
      throw PdfRendererError.renderFailed
    }

    result([
      "documentId": documentId,
      "pageIndex": pageIndex,
      "width": width,
      "height": height,
      "pngBytes": FlutterStandardTypedData(bytes: pngData),
    ])
  }

  private func closeDocument(_ call: FlutterMethodCall, result: FlutterResult) throws {
    let arguments = try requireArguments(call)
    let documentId = try requireInt(arguments, key: "documentId")
    if let document = documents.removeValue(forKey: documentId) {
      close(document)
    }
    result(nil)
  }

  private func requireArguments(_ call: FlutterMethodCall) throws -> [String: Any] {
    guard let arguments = call.arguments as? [String: Any] else {
      throw PdfRendererError.invalidArgument("Expected method arguments.")
    }
    return arguments
  }

  private func requireString(_ arguments: [String: Any], key: String) throws -> String {
    guard let value = arguments[key] as? String else {
      throw PdfRendererError.invalidArgument("\(key) is required.")
    }
    return value
  }

  private func requireBytes(_ arguments: [String: Any], key: String) throws -> Data {
    if let typedData = arguments[key] as? FlutterStandardTypedData {
      return typedData.data
    }
    throw PdfRendererError.invalidArgument("\(key) is required.")
  }

  private func requireInt(_ arguments: [String: Any], key: String) throws -> Int {
    guard let value = arguments[key] as? NSNumber else {
      throw PdfRendererError.invalidArgument("\(key) is required.")
    }
    return value.intValue
  }

  private func requireDouble(_ arguments: [String: Any], key: String) throws -> Double {
    guard let value = arguments[key] as? NSNumber else {
      throw PdfRendererError.invalidArgument("\(key) is required.")
    }
    return value.doubleValue
  }

  private func requireDocument(_ documentId: Int) throws -> OpenDocument {
    guard let document = documents[documentId] else {
      throw PdfRendererError.unknownDocument(documentId)
    }
    return document
  }

  private func requirePage(documentId: Int, pageIndex: Int) throws -> PDFPage {
    let document = try requireDocument(documentId)
    guard let page = document.document.page(at: pageIndex) else {
      throw PdfRendererError.invalidPageIndex(pageIndex)
    }
    return page
  }

  private func close(_ document: OpenDocument) {
    if let tempFileUrl = document.tempFileUrl {
      try? FileManager.default.removeItem(at: tempFileUrl)
    }
  }
}

private struct OpenDocument {
  let document: PDFDocument
  let tempFileUrl: URL?
}

private enum PdfRendererError: LocalizedError {
  case documentOpenFailed
  case fileNotFound(String)
  case invalidArgument(String)
  case invalidPageIndex(Int)
  case renderFailed
  case unknownDocument(Int)
  case unsupportedSourceType(String)

  var errorDescription: String? {
    switch self {
    case .documentOpenFailed:
      return "Failed to open the PDF document."
    case let .fileNotFound(path):
      return "PDF file does not exist: \(path)"
    case let .invalidArgument(message):
      return message
    case let .invalidPageIndex(pageIndex):
      return "Unknown pageIndex: \(pageIndex)"
    case .renderFailed:
      return "Failed to render the PDF page."
    case let .unknownDocument(documentId):
      return "Unknown documentId: \(documentId)"
    case let .unsupportedSourceType(sourceType):
      return "Unsupported sourceType: \(sourceType)"
    }
  }
}

private func uiColorFromArgb(_ color: Int) -> UIColor {
  let alpha = CGFloat((color >> 24) & 0xFF) / 255.0
  let red = CGFloat((color >> 16) & 0xFF) / 255.0
  let green = CGFloat((color >> 8) & 0xFF) / 255.0
  let blue = CGFloat(color & 0xFF) / 255.0
  return UIColor(red: red, green: green, blue: blue, alpha: alpha)
}
