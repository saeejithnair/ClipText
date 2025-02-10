//
//  ContentView.swift
//  ClipText
//
//  Created by Saeejith Nair on 2025-01-25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.viewfinder")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)
            
            Text("ClipText")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Press ⌃⇧9 to capture a region of your screen")
                .font(.headline)
            
            Text("The text content will be automatically copied to your clipboard")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(width: 300, height: 200)
    }
}

#Preview {
    ContentView()
}
