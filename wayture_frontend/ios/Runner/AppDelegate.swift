import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // BEFORE BUILDING ON iOS: replace GOOGLE_MAPS_API_KEY_HERE with your real
    // Google Maps API key. Make sure "Maps SDK for iOS" is enabled and the key
    // is restricted to bundle id com.example.wayture in the GCP console.
    GMSServices.provideAPIKey("GOOGLE_MAPS_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
