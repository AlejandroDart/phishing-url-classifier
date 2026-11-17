import Flutter
import ImageIO
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "detector_url/ocr",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = call.arguments as? String, !path.isEmpty else {
        result(FlutterError(code: "image_invalid", message: "La imagen no está disponible.", details: nil))
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        let url = URL(fileURLWithPath: path)
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        let metadata = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) }
        let properties = metadata as? [String: Any]
        let orientationValue = properties?[kCGImagePropertyOrientation as String] as? NSNumber
        let orientation = orientationValue.flatMap { CGImagePropertyOrientation(rawValue: $0.uint32Value) } ?? .up

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(url: url, orientation: orientation)
        do {
          try handler.perform([request])
          let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
          DispatchQueue.main.async { result(lines.joined(separator: "\n")) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "ocr_failed", message: "No se pudo leer la imagen.", details: nil))
          }
        }
      }
    }
  }
}
