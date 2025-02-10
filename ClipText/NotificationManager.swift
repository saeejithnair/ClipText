import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }
    
    func showSuccess(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "ClipText"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing success notification: \(error)")
            }
        }
    }
    
    func showError(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "ClipText Error"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing error notification: \(error)")
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