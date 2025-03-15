//
//  TrustPactApp.swift
//  TrustPact
//
//  Created by Erasmus Austin  on 05/03/2025.
//

import SwiftUI
import FirebaseCore

@main
struct TrustPactApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
