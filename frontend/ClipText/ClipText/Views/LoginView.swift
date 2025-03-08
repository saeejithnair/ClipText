import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.bubble.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("ClipText")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your AI-powered text assistant")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer().frame(height: 30)
            
            Button(action: authViewModel.login) {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.headline)
                    Text("Sign in with Auth0")
                        .fontWeight(.semibold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
} 