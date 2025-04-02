//
//  AppDelegate.swift
//  CallKitDemo
//
//  Created by Nirzar Gandhi on 25/02/25.
//

import UIKit
import AVFoundation
import PushKit
import CallKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties
    internal var window: UIWindow?
    var navController : UINavigationController?
    
    lazy var uuid = UUID()
    
    
    // MARK: - RootView Setup
    func setRootViewController(rootVC: UIViewController) {
        
        self.navController = UINavigationController(rootViewController: rootVC)
        self.window?.rootViewController = self.navController
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Set Root Controller
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.backgroundColor = .white
        let homeVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HomeVC") as! HomeVC
        self.setRootViewController(rootVC: homeVC)
        
        self.window?.makeKeyAndVisible()
        
        application.applicationIconBadgeNumber = -1
        
        self.registerForPushNotifications()
        self.registratForVOIP()
        
        return true
    }
}


// MARK: - Call Back
extension AppDelegate {
    
    private func microphonePermission() -> Bool {
        
        var permission = false
        
        switch AVAudioSession.sharedInstance().recordPermission {
            
        case .granted:
            permission = true
            
        case .denied:
            permission = false
            
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ granted in
                permission = granted
            })
            
        @unknown default:
            break
        }
        
        return permission
    }
}


// MARK: - Remote and PushKit Notification Handler
extension AppDelegate: UNUserNotificationCenterDelegate, PKPushRegistryDelegate {
    
    // Register for APNS
    func registerForPushNotifications() {
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound,.alert,.badge]) { (granted, error) in
            
            guard granted else { return }
            self.getNotificationSettings()
        }
    }
    
    // Register for VoIP
    private func registratForVOIP() {
        
        let mainQueue = DispatchQueue.main
        let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
    }
    
    private func getNotificationSettings() {
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            
            print("Notification settings: \(settings)")
            
            guard settings.authorizationStatus == .authorized else { return }
            
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    // APNS Register and Fail
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        print("\nAPNs device token: " + deviceTokenString + "\n")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("\nFailed to register:", error)
    }
    
    // VoIP Register and Fail
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        
        let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
        print("\nVoIP token: " + deviceToken + "\n")
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("\nVoIP failed to register:", type.rawValue)
    }
    
    // MARK: - UNUserNotificationCenter Delegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler: @escaping (UNNotificationPresentationOptions)->()) {
        
        // Show Notification Banner List (Handler)
        withCompletionHandler([.alert, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let _ = response.notification.request.content.userInfo
        
        UIApplication.shared.applicationIconBadgeNumber = -1
        
        completionHandler()
    }
    
    // MARK: - VoIP Notification Delegate
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        
        print("---------- VoIP Notification ----------\n\(payload.dictionaryPayload)")
        
        self.handleIncomingCall(payload: payload)
        completion()
    }
    
    private func handleIncomingCall(payload: PKPushPayload) {
        
        var callerName = ""
        
        guard let data = payload.dictionaryPayload as? [String: Any],
              let action = data["action"] as? String,
              let uuidStr = data["uuid"] as? String else {
            return
        }
        
        if uuidStr.isEmpty {
            self.uuid = UUID()
        } else {
            self.uuid = UUID(uuidString: uuidStr)!
        }
        
        if let name = data["callerName"] as? String {
            callerName = name
        }
        
        if action == "startCall" {
            
            if CallKitManager.shared.isOnPhoneCall() {
                
                CallKitManager.shared.reportIncomingCall(uuid: self.uuid, callerName: callerName)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    CallKitManager.shared.endCall(uuid: self.uuid)
                }
                
                return
                
            } else {
                CallKitManager.shared.reportIncomingCall(uuid: self.uuid, callerName: callerName)
            }
            
        } else {
            CallKitManager.shared.endCall(uuid: self.uuid)
        }
    }
}

