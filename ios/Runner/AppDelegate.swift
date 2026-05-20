import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let badgeChannel = FlutterMethodChannel(
        name: "my_app/app_icon_badge",
        binaryMessenger: controller.binaryMessenger
      )

      badgeChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "setBadgeCount" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard let count = call.arguments as? NSNumber else {
          result(
            FlutterError(
              code: "BAD_ARGS",
              message: "Expected an integer badge count.",
              details: nil
            )
          )
          return
        }

        self?.setAppIconBadge(count.intValue, result: result)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setAppIconBadge(_ count: Int, result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { _, error in
      if let error = error {
        result(
          FlutterError(
            code: "BADGE_PERMISSION_ERROR",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }

      DispatchQueue.main.async {
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
              result(
                FlutterError(
                  code: "BADGE_UPDATE_ERROR",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            } else {
              result(nil)
            }
          }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(nil)
        }
      }
    }
  }
}
