import SwiftUI

struct GeminiView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var prompt: String = ""
    @State private var response: String = ""
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Input field
                TextField("Ask Gemini something...", text: $prompt)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
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
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Response display
                if !response.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Response:")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            Text(response)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
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
    
    private func sendPrompt() {
        guard let user = authViewModel.user else { return }
        
        isLoading = true
        error = nil
        
        APIService.shared.sendPrompt(prompt: prompt, token: user.accessToken) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let text):
                    self.response = text
                case .failure(let error):
                    self.error = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
} 