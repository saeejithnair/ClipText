import SwiftUI
import Auth0

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated: Bool = false
    
    func login() {
        Auth0
            .webAuth()
            .audience("https://dev-1onvtxdgc5z1ojw8.us.auth0.com/userinfo")
            .scope("openid profile email")
            .start { result in
                switch result {
                case .success(let credentials):
                    if let user = User(from: credentials.idToken, accessToken: credentials.accessToken) {
                        DispatchQueue.main.async {
                            self.user = user
                            self.isAuthenticated = true
                        }
                    }
                case .failure(let error):
                    print("Failed with: \(error)")
                }
            }
    }
    
    func logout() {
        Auth0
            .webAuth()
            .clearSession { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.user = nil
                        self.isAuthenticated = false
                    }
                case .failure(let error):
                    print("Failed with: \(error)")
                }
            }
    }
} 