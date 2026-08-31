import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  static let launchRouteKey = "flutter.ff_coop_link"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Persist before super so Flutter's SharedPreferences cache already sees
    // the tap URL. UIScene delivers terminated-state taps here, not in
    // application:didFinishLaunchingWithOptions: — getInitialMessage() can
    // lose that race (FlutterFire #17991 / #18352).
    if let response = connectionOptions.notificationResponse {
      Self.capture(from: response.notification.request.content.userInfo)
    }

    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  static func capture(from payload: [AnyHashable: Any]) {
    guard let destination = destination(inside: payload) else { return }
    persist(destination)
  }

  static func persist(_ destination: String) {
    let defaults = UserDefaults.standard
    defaults.set(destination, forKey: launchRouteKey)
  }

  static func destination(
    inside payload: [AnyHashable: Any]
  ) -> String? {
    let candidates: Set<String> = [
      "deep_link", "target", "url", "deeplink", "link", "href", "redirect",
    ]

    func looksLikeURL(_ value: String) -> Bool {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard let url = URL(string: trimmed), let scheme = url.scheme else {
        return false
      }
      return scheme == "http" || scheme == "https"
    }

    func decodeJSON(_ text: String) -> [AnyHashable: Any]? {
      guard let data = text.data(using: .utf8) else { return nil }
      return (try? JSONSerialization.jsonObject(with: data)) as? [AnyHashable: Any]
    }

    func firstValue(in dictionary: [AnyHashable: Any]) -> String? {
      for (key, raw) in dictionary {
        let name = String(describing: key).lowercased()
        guard candidates.contains(name) else { continue }
        if let value = raw as? String {
          let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
          if looksLikeURL(trimmed) { return trimmed }
          if let nested = decodeJSON(trimmed), let found = firstValue(in: nested) {
            return found
          }
        }
      }
      for container in ["payload", "data"] {
        if let nested = dictionary[container] as? [AnyHashable: Any],
           let value = firstValue(in: nested) {
          return value
        }
        if let text = dictionary[container] as? String,
           let nested = decodeJSON(text),
           let value = firstValue(in: nested) {
          return value
        }
      }
      return nil
    }

    return firstValue(in: payload)
  }
}
