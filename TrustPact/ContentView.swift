//
//  ContentView.swift
//  TrustPact
//
//  Created by Erasmus Austin  on 05/03/2025.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @StateObject private var authService = AuthenticationService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Group {
                if authService.isAuthenticated {
                    // View for authenticated users
                    LoggedInView(authService: authService)
                } else {
                    // Login/Signup form
                    VStack(spacing: 20) {
                        // Logo or app title
                        Image(systemName: "lock.shield")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                            .padding(.bottom, 20)
                        
                        Text("TrustPact")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.bottom, 30)
                        
                        // Form fields
                        VStack(spacing: 15) {
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            SecureField("Password", text: $password)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        // Action buttons
                        VStack(spacing: 15) {
                            Button(action: performAuthAction) {
                                Text(isLoggingIn ? "Log In" : "Sign Up")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .disabled(email.isEmpty || password.isEmpty)
                            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                            
                            Button(action: {
                                isLoggingIn.toggle()
                                email = ""
                                password = ""
                            }) {
                                Text(isLoggingIn ? "Don't have an account? Sign Up" : "Already have an account? Log In")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding()
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("Authentication"),
                            message: Text(alertMessage),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }
            }
            .navigationBarTitle(authService.isAuthenticated ? "Welcome" : "", displayMode: .inline)
        }
    }
    
    private func performAuthAction() {
        if isLoggingIn {
            authService.login(email: email, password: password) { success, error in
                handleAuthResult(success: success, error: error, action: "login")
            }
        } else {
            authService.signUp(email: email, password: password) { success, error in
                handleAuthResult(success: success, error: error, action: "signup")
            }
        }
    }
    
    private func handleAuthResult(success: Bool, error: String?, action: String) {
        if success {
            // Clear the form after successful auth
            email = ""
            password = ""
        } else if let errorMessage = error {
            alertMessage = "Failed to \(action): \(errorMessage)"
            showAlert = true
        }
    }
}

// View for authenticated users
struct LoggedInView: View {
    @ObservedObject var authService: AuthenticationService
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.green)
            
            Text("Welcome!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let user = authService.currentUser {
                Text("You are signed in as:")
                    .font(.headline)
                
                Text(user.email ?? "No email")
                    .font(.title3)
                    .padding()
            }
            
            Button(action: {
                authService.signOut()
            }) {
                Text("Sign Out")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
            }
            .padding(.top, 30)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
