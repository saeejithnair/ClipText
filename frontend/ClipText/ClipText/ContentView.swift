//
//  ContentView.swift
//  ClipText
//
//  Created by Saeejith Nair on 2025-03-07.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                GeminiView(authViewModel: authViewModel)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
