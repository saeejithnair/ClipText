import AppKit
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    func showSuccess(message: String) {
        showNotification(title: "Success", message: message)
    }
    
    func showError(message: String) {
        showNotification(title: "Error", message: message)
    }
    
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }
    
    func showProcessing() {
        let content = UNMutableNotificationContent()
        content.title = "ClipText"
        content.body = "Processing image..."
        
        let request = UNNotificationRequest(
            identifier: "processing",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing processing notification: \(error)")
            }
        }
    }
    
    func removeProcessingNotification() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["processing"])
    }
} 