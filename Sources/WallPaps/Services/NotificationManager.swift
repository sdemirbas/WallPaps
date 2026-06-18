import Foundation
import UserNotifications

/// Local "new artwork / artwork of the day" notifications.
/// Guards against running outside an app bundle (e.g. `swift run`, self-test),
/// where `UNUserNotificationCenter.current()` is unavailable.
enum NotificationManager {

    private static var isBundled: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() {
        guard isBundled else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Post a notification for the given artwork, attaching its 4K master as a thumbnail.
    static func post(title: String, body: String, imagePath: String?) {
        guard isBundled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let path = imagePath, FileManager.default.fileExists(atPath: path),
           let attachment = try? UNNotificationAttachment(
               identifier: "artwork", url: URL(fileURLWithPath: path), options: nil) {
            content.attachments = [attachment]
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
