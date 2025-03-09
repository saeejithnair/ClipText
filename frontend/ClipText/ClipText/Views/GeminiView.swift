import SwiftUI
import UniformTypeIdentifiers
import AppKit

// Constants for user preferences
private struct UserPreferenceKeys {
    static let autoClipboardCopy = "autoClipboardCopy"
}

struct GeminiView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var prompt: String = ""
    @State private var response: String = ""
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @State private var selectedImage: NSImage? = nil
    @State private var showCopiedToast: Bool = false
    @State private var autoCopyToClipboard: Bool = UserDefaults.standard.object(forKey: UserPreferenceKeys.autoClipboardCopy) == nil ? true : UserDefaults.standard.bool(forKey: UserPreferenceKeys.autoClipboardCopy)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Input field
                TextField("Ask Gemini something...", text: $prompt)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                // Image selection
                HStack {
                    if let image = selectedImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 100)
                            .cornerRadius(8)
                            
                        Button(action: {
                            selectedImage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: {
                        openImagePicker()
                    }) {
                        HStack {
                            Image(systemName: "photo")
                            Text(selectedImage == nil ? "Add Image" : "Change Image")
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Send button
                Button(action: sendPrompt) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text(isLoading ? "Processing..." : "Send")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isLoading || prompt.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .disabled(isLoading || prompt.isEmpty)
                
                // Error display
                if let error = error {
                    ScrollView {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                }
                
                // Response display
                if !response.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Response:")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                Spacer()
                                
                                // Clear response button
                                Button(action: clearResponse) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Clear")
                                    }
                                    .padding(6)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .keyboardShortcut(.delete, modifiers: [.command])
                                .help("Clear response (⌘⌫)")
                                
                                // Copy to clipboard button
                                Button(action: copyToClipboard) {
                                    HStack {
                                        Image(systemName: "doc.on.clipboard")
                                        Text("Copy")
                                    }
                                    .padding(6)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .keyboardShortcut("c", modifiers: [.command])
                                .help("Copy to clipboard (⌘C)")
                            }
                            
                            Text(response)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                                .textSelection(.enabled) // Enable text selection for manual copying
                            
                            // Improved auto-copy toggle
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { autoCopyToClipboard },
                                    set: { 
                                        autoCopyToClipboard = $0
                                        // Save preference when changed
                                        UserDefaults.standard.set($0, forKey: UserPreferenceKeys.autoClipboardCopy)
                                    }
                                )) {
                                    Text("Auto-copy responses")
                                        .font(.subheadline)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                
                                Spacer()
                                
                                Text("Automatically copy new responses to clipboard")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Clipboard toast notification
                    clipboardToastView
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("ClipText")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: authViewModel.logout) {
                        Text("Logout")
                    }
                }
            }
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(response, forType: .string)
        
        withAnimation {
            showCopiedToast = true
        }
    }
    
    private func clearResponse() {
        withAnimation {
            response = ""
        }
    }
    
    // Updated toast message view
    private var clipboardToastView: some View {
        Group {
            if showCopiedToast {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text(autoCopyToClipboard ? "Auto-copied to clipboard!" : "Copied to clipboard!")
                }
                .padding(10)
                .background(Color.green.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 2)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showCopiedToast = false
                        }
                    }
                }
            }
        }
    }
    
    private func openImagePicker() {
        let openPanel = NSOpenPanel()
        openPanel.prompt = "Select Image"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.jpeg, .png, .image]
        
        print("Opening NSOpenPanel")
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                print("Selected file: \(url)")
                print("File path: \(url.path)")
                print("File exists: \(FileManager.default.fileExists(atPath: url.path))")
                
                // Get file attributes
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    print("File attributes: \(attributes)")
                    if let fileSize = attributes[.size] as? NSNumber {
                        print("File size: \(fileSize.intValue) bytes")
                    }
                    if let fileType = attributes[.type] as? String {
                        print("File type: \(fileType)")
                    }
                } catch {
                    print("Failed to get file attributes: \(error)")
                }
                
                // Get file UTI
                let resourceValues = try? url.resourceValues(forKeys: [.typeIdentifierKey])
                if let uti = resourceValues?.typeIdentifier {
                    print("File UTI: \(uti)")
                }
                
                do {
                    // Try to read the file directly
                    print("Attempting to read file data")
                    let imageData = try Data(contentsOf: url)
                    print("Successfully read \(imageData.count) bytes")
                    
                    // Check first few bytes to identify file type
                    let header = imageData.prefix(16)
                    print("File header (hex): \(header.map { String(format: "%02x", $0) }.joined())")
                    
                    if let image = NSImage(data: imageData) {
                        print("Successfully created NSImage from data")
                        print("Image size: \(image.size)")
                        print("Image representations: \(image.representations.count)")
                        
                        for (index, rep) in image.representations.enumerated() {
                            print("Representation \(index): \(type(of: rep)), size: \(rep.size), bitsPerSample: \(rep.bitsPerSample)")
                        }
                        
                        DispatchQueue.main.async {
                            self.selectedImage = image
                        }
                    } else {
                        print("Failed to create NSImage from data")
                        DispatchQueue.main.async {
                            self.error = "Failed to create image from selected file"
                        }
                    }
                } catch {
                    print("Error reading file: \(error)")
                    DispatchQueue.main.async {
                        self.error = "Error reading file: \(error.localizedDescription)"
                    }
                }
            } else {
                print("User cancelled or no file selected")
            }
        }
    }
    
    private func sendPrompt() {
        guard let user = authViewModel.user else { return }
        
        isLoading = true
        error = nil
        
        print("Sending prompt: \"\(prompt)\"")
        
        if let image = selectedImage {
            print("Sending prompt with image")
            APIService.shared.sendPromptWithImage(prompt: prompt, image: image, token: user.accessToken) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    switch result {
                    case .success(let text):
                        print("Received successful response: \"\(text.prefix(50))...\"")
                        self.response = text
                        
                        // Update AppDelegate with last response
                        self.appDelegate.updateLastResponse(text)
                        
                        // Auto-copy to clipboard if enabled
                        if self.autoCopyToClipboard {
                            self.copyToClipboard()
                        }
                    case .failure(let error):
                        print("Received error response: \(error)")
                        if let nsError = error as NSError? {
                            if let responseData = nsError.userInfo["responseData"] as? String {
                                self.error = "Error: \(nsError.domain)\n\nResponse: \(responseData)"
                            } else {
                                self.error = "Error: \(nsError.domain)"
                            }
                        } else {
                            self.error = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        } else {
            print("Sending prompt without image")
            APIService.shared.sendPrompt(prompt: prompt, token: user.accessToken) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    switch result {
                    case .success(let text):
                        print("Received successful response: \"\(text.prefix(50))...\"")
                        self.response = text
                        
                        // Update AppDelegate with last response
                        self.appDelegate.updateLastResponse(text)
                        
                        // Auto-copy to clipboard if enabled
                        if self.autoCopyToClipboard {
                            self.copyToClipboard()
                        }
                    case .failure(let error):
                        print("Received error response: \(error)")
                        if let nsError = error as NSError? {
                            if let responseData = nsError.userInfo["responseData"] as? String {
                                self.error = "Error: \(nsError.domain)\n\nResponse: \(responseData)"
                            } else {
                                self.error = "Error: \(nsError.domain)"
                            }
                        } else {
                            self.error = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
} 