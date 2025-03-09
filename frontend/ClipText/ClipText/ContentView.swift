//
//  ContentView.swift
//  ClipText
//
//  Created by Saeejith Nair on 2025-03-07.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @EnvironmentObject var appDelegate: AppDelegate
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                GeminiView(authViewModel: authViewModel)
                    .environmentObject(appDelegate)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDelegate())
}
