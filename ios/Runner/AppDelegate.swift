import UIKit
import Flutter
import GoogleMaps  // Import Google Maps SDK

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Provide the Google Maps API key
    GMSServices.provideAPIKey("AIzaSyBPc5Z8Rq5cYI8KrBHAtT-8QDSGlx4pzo0")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
