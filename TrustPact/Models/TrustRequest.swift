//
//  TrustRequest.swift
//  TrustPact
//
//  Created for TrustPact app
//

import Foundation
import FirebaseFirestoreSwift

/// Model representing a trust request between users
struct TrustRequest: Identifiable, Codable {
    /// Status options for a trust request
    enum Status: String, Codable {
        case pending
        case accepted
        case declined
        case revoked
    }
    
    /// Firestore document ID
    @DocumentID var id: String?
    
    /// Unique identifier for the request
    let requestId: String
    
    /// ID of the user sending the request
    let senderId: String
    
    /// ID of the user receiving the request
    let receiverId: String
    
    /// Current status of the request
    let status: Status
    
    /// Timestamp when the request was created
    let timestamp: Date
    
    /// Expiration date for the request
    let expiration: Date
    
    /// The user's identifier in Firestore
    var documentId: String {
        return id ?? UUID().uuidString
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case requestId
        case senderId
        case receiverId
        case status
        case timestamp
        case expiration
    }
    
    /// Initialize with default values
    init(requestId: String = UUID().uuidString,
         senderId: String,
         receiverId: String,
         status: Status = .pending,
         timestamp: Date = Date(),
         expiration: Date? = nil,
         id: String? = nil) {
        self.requestId = requestId
        self.senderId = senderId
        self.receiverId = receiverId
        self.status = status
        self.timestamp = timestamp
        self.expiration = expiration ?? Calendar.current.date(byAdding: .day, value: 1, to: timestamp)!
        self.id = id
    }
    
    /// Helper method to create a copy of this trust request with updated status
    func withStatus(_ newStatus: Status) -> TrustRequest {
        return TrustRequest(
            requestId: self.requestId,
            senderId: self.senderId,
            receiverId: self.receiverId,
            status: newStatus,
            timestamp: self.timestamp,
            expiration: self.expiration,
            id: self.id
        )
    }
}

// MARK: - Firestore Helpers
extension TrustRequest {
    /// Firestore collection name
    static let collectionName = "trustRequests"
    
    /// Returns the Firestore document path for this request
    var documentPath: String {
        return "\(TrustRequest.collectionName)/\(documentId)"
    }
    
    /// Returns true if the request is still valid (not expired)
    var isValid: Bool {
        return Date() < expiration
    }
    
    /// Returns true if the request can be accepted (is pending and not expired)
    var canBeAccepted: Bool {
        return status == .pending && isValid
    }
}

