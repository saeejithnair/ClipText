//
//  ContentView.swift
//  ClipText
//
//  Created by Saeejith Nair on 2025-01-25.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background with ultra-subtle gradient and blur
            VisualEffectView()
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 32) {
                // Animated Icon
                ZStack {
                    // Glowing background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.8),
                                    Color.blue.opacity(0.4)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                        .opacity(isAnimating ? 0.8 : 0.4)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    
                    // Main icon circle
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.blue.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // Icon
                    Image(systemName: "text.viewfinder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, value: isAnimating)
                }
                .scaleEffect(isAnimating ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                // Text Content with refined typography
                VStack(spacing: 16) {
                    Text("ClipText")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(nsColor: .labelColor),
                                    Color(nsColor: .labelColor).opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Hotkey visualization
                    HStack(spacing: 6) {
                        ForEach(["⌃", "⇧", "9"], id: \.self) { key in
                            KeyCapsuleView(text: key)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 4)
                    
                    Text("Instantly capture text\nfrom your screen")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .opacity(0.9)
                }
            }
            .padding(40)
        }
        .frame(width: 320, height: 320)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

struct KeyCapsuleView: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(Color(nsColor: .labelColor))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        Color(nsColor: colorScheme == .dark ? .textBackgroundColor : .controlBackgroundColor)
                            .opacity(colorScheme == .dark ? 0.5 : 0.8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.2 : 0.4),
                                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                radius: 2,
                x: 0,
                y: 1
            )
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

#Preview {
    ContentView()
}
