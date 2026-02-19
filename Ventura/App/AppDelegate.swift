//
//  AppDelegate.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/19/26.
//

import UIKit
import CarPlay

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    // Explicitly route CarPlay scenes to our delegate.
    // Without this, SwiftUI's internal scene routing overrides the Info.plist config.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(name: "CarPlay Configuration", sessionRole: .carTemplateApplication)
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
        
        // For the phone's main window scene, return a default config.
        // SwiftUI will apply its own delegate internally.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
