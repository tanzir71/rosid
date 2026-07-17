import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludePrivateDataFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func excludePrivateDataFromBackup() {
    let fileManager = FileManager.default
    for directory in [
      FileManager.SearchPathDirectory.documentDirectory,
      FileManager.SearchPathDirectory.applicationSupportDirectory,
    ] {
      guard var url = fileManager.urls(for: directory, in: .userDomainMask).first else {
        continue
      }
      try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? url.setResourceValues(values)
    }
  }
}
