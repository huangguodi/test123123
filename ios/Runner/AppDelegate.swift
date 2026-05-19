import Flutter
import UIKit
import CryptoKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let securityChannel = FlutterMethodChannel(name: "com.example.address/security",
                                              binaryMessenger: controller.binaryMessenger)
    
    securityChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getAppSignature" {
        self.getAppSignature(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getAppSignature(result: FlutterResult) {
    if #available(iOS 13.0, *) {
        // Priority: Integrity Check File (Custom Hash)
        // Used for obfuscation key generation to bypass App Store re-signing issues
        if let keyPath = Bundle.main.path(forResource: "integrity_check", ofType: nil) {
             do {
                let data = try Data(contentsOf: URL(fileURLWithPath: keyPath))
                let digest = SHA256.hash(data: data)
                let hexString = digest.map { String(format: "%02X", $0) }.joined(separator: ":")
                result(hexString)
                return
             } catch {}
        }

        // 1. Try to hash embedded.mobileprovision (Standard for AdHoc/Store)
        if let provisionPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: provisionPath))
                let digest = SHA256.hash(data: data)
                let hexString = digest.map { String(format: "%02X", $0) }.joined(separator: ":")
                result(hexString)
                return
            } catch {}
        }
        
        // 2. Fallback: Hash the Info.plist (For Simulator/Debug)
        if let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist") {
             do {
                let data = try Data(contentsOf: URL(fileURLWithPath: infoPath))
                let digest = SHA256.hash(data: data)
                let hexString = digest.map { String(format: "%02X", $0) }.joined(separator: ":")
                result(hexString)
                return
             } catch {}
        }
    }
    
    result(FlutterError(code: "SIG_ERR", message: "Could not retrieve signature", details: nil))
  }
}
