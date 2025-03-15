//
//  AuthenticationService.swift
//  TrustPact
//
//  Created by TrustPact Team
//

import Foundation
import FirebaseAuth
import SwiftUI
import Combine

/// A service that handles all authentication-related functionality
class AuthenticationService: ObservableObject {
    // MARK: - Singleton
    
    /// Shared instance of the authentication service
    static let shared = AuthenticationService()
    
    /// Current authenticated user (if any)
    @Published private(set) var currentUser: User?
    
    /// Check if user is logged in
    @Published private(set) var isUserLoggedIn: Bool = false
    
    /// Convenience property for ContentView
    @Published var isAuthenticated: Bool = false
    
    /// Auth state listener handle
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Setup Firebase Auth state listener
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            // Update published properties
            self.currentUser = user
            self.isUserLoggedIn = user != nil
            self.isAuthenticated = user != nil
        }
    }
    
    deinit {
        // Remove auth state listener when instance is deallocated
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Create a new user account with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - completion: Callback with result containing user or error
    func signUp(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("Error signing up: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let user = authResult?.user else {
                let error = NSError(domain: "AuthenticationService", code: 0, 
                                    userInfo: [NSLocalizedDescriptionKey: "Failed to get user after sign up"])
                completion(.failure(error))
                return
            }
            
            print("User signed up successfully!")
            
            // Published properties will be updated through the auth state listener
            completion(.success(user))
        }
    }
    
    /// Create a new user account with email and password (Convenience method for ContentView)
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - completion: Callback with success flag and optional error message
    func signUp(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("Error signing up: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard authResult?.user != nil else {
                completion(false, "Failed to get user after sign up")
                return
            }
            
            print("User signed up successfully!")
            
            // Published properties will be updated through the auth state listener
            completion(true, nil)
        }
    }
    
    /// Login with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - completion: Callback with result containing user or error
    func login(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("Error logging in: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let user = authResult?.user else {
                let error = NSError(domain: "AuthenticationService", code: 1, 
                                    userInfo: [NSLocalizedDescriptionKey: "Failed to get user after login"])
                completion(.failure(error))
                return
            }
            
            print("User logged in successfully!")
            
            // Published properties will be updated through the auth state listener
            completion(.success(user))
        }
    }
    
    /// Login with email and password (Convenience method for ContentView)
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - completion: Callback with success flag and optional error message
    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("Error logging in: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard authResult?.user != nil else {
                completion(false, "Failed to get user after login")
                return
            }
            
            print("User logged in successfully!")
            
            // Published properties will be updated through the auth state listener
            completion(true, nil)
        }
    }
    
    /// Log out the current user
    /// - Parameter completion: Callback with optional error
    func logout(completion: @escaping (Error?) -> Void) {
        do {
            try Auth.auth().signOut()
            print("User logged out successfully")
            
            // Published properties will be updated through the auth state listener
            completion(nil)
        } catch let error {
            print("Error signing out: \(error.localizedDescription)")
            completion(error)
        }
    }
    
    /// Sign out the current user (Convenience method for ContentView without completion handler)
    func signOut() {
        do {
            try Auth.auth().signOut()
            print("User logged out successfully")
            
            // Published properties will be updated through the auth state listener
        } catch let error {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    /// Send password reset email
    ///   - email: Email address for account that needs password reset
    ///   - completion: Callback with optional error
    func resetPassword(email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print("Error sending password reset: \(error.localizedDescription)")
                completion(error)
            } else {
                print("Password reset email sent successfully")
                completion(nil)
            }
        }
    }
    
    /// Update user's profile information
    /// - Parameters:
    ///   - displayName: New display name (optional)
    ///   - photoURL: New photo URL (optional)
    ///   - completion: Callback with optional error
    func updateProfile(displayName: String? = nil, photoURL: URL? = nil, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            let error = NSError(domain: "AuthenticationService", code: 2, 
                                userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
            completion(error)
            return
        }
        
        let changeRequest = user.createProfileChangeRequest()
        
        if let displayName = displayName {
            changeRequest.displayName = displayName
        }
        
        if let photoURL = photoURL {
            changeRequest.photoURL = photoURL
        }
        
        changeRequest.commitChanges { error in
            if let error = error {
                print("Error updating profile: \(error.localizedDescription)")
                completion(error)
            } else {
                print("Profile updated successfully")
                completion(nil)
            }
        }
    }
}

