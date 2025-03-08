//
//  ClipTextApp.swift
//  ClipText
//
//  Created by Saeejith Nair on 2025-03-07.
//

import SwiftUI
import Auth0

@main
struct ClipTextApp: App {
    init() {
        configureAuth0()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func configureAuth0() {
        guard let path = Bundle.main.path(forResource: "Auth0", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
              let domain = dict["Domain"] as? String,
              let clientId = dict["ClientId"] as? String else {
            print("Auth0 configuration error: missing or invalid Auth0.plist file")
            return
        }
        
        // We don't need to store these instances as Auth0 manages them internally
        // We're just making sure the configuration is loaded
        _ = Auth0.authentication(clientId: clientId, domain: domain)
        _ = Auth0.webAuth(clientId: clientId, domain: domain)
    }
}
