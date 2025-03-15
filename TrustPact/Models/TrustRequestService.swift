import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class TrustRequestService: ObservableObject {
    private let db = Firestore.firestore()
    private let requestsCollection = "trustRequests"
    
    @Published var sentRequests: [TrustRequest] = []
    @Published var receivedRequests: [TrustRequest] = []
    
    private var listenerRegistrations: [ListenerRegistration] = []
    
    static let shared = TrustRequestService()
    
    private init() {}
    
    deinit {
        // Remove all listeners when the service is deallocated
        removeAllListeners()
    }
    
    // MARK: - Create Request
    
    func createRequest(receiverId: String, expiration: Date? = nil) async throws -> TrustRequest {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "TrustRequestService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let requestId = UUID().uuidString
        let timestamp = Date()
        // Default expiration to 48 hours if not specified
        let expirationDate = expiration ?? Calendar.current.date(byAdding: .hour, value: 48, to: timestamp)!
        
        let request = TrustRequest(
            id: requestId,
            requestId: requestId,
            senderId: currentUser.uid,
            receiverId: receiverId,
            status: .pending,
            timestamp: timestamp,
            expiration: expirationDate
        )
        
        let data = try request.asDictionary()
        
        try await db.collection(requestsCollection).document(requestId).setData(data)
        return request
    }
    
    // Convenience method with completion handler
    func createRequest(receiverId: String, expiration: Date? = nil, completion: @escaping (Result<TrustRequest, Error>) -> Void) {
        Task {
            do {
                let request = try await createRequest(receiverId: receiverId, expiration: expiration)
                DispatchQueue.main.async {
                    completion(.success(request))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Method with explicit senderId for testing or admin purposes
    func createRequest(senderId: String, receiverId: String, expiration: Date? = nil, completion: @escaping (Result<TrustRequest, Error>) -> Void) {
        let requestId = UUID().uuidString
        let timestamp = Date()
        // Default expiration to 48 hours if not specified
        let expirationDate = expiration ?? Calendar.current.date(byAdding: .hour, value: 48, to: timestamp)!
        
        let request = TrustRequest(
            id: requestId,
            requestId: requestId,
            senderId: senderId,
            receiverId: receiverId,
            status: .pending,
            timestamp: timestamp,
            expiration: expirationDate
        )
        
        Task {
            do {
                let data = try request.asDictionary()
                try await db.collection(requestsCollection).document(requestId).setData(data)
                DispatchQueue.main.async {
                    completion(.success(request))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Fetch Requests
    
    func fetchSentRequests() async throws -> [TrustRequest] {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "TrustRequestService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let snapshot = try await db.collection(requestsCollection)
            .whereField("senderId", isEqualTo: currentUser.uid)
            .getDocuments()
        
        let requests = try snapshot.documents.compactMap { document -> TrustRequest? in
            try document.data(as: TrustRequest.self)
        }
        
        DispatchQueue.main.async {
            self.sentRequests = requests
        }
        
        return requests
    }
    
    func fetchSentRequests(completion: @escaping (Result<[TrustRequest], Error>) -> Void) {
        Task {
            do {
                let requests = try await fetchSentRequests()
                DispatchQueue.main.async {
                    completion(.success(requests))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchReceivedRequests() async throws -> [TrustRequest] {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "TrustRequestService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let snapshot = try await db.collection(requestsCollection)
            .whereField("receiverId", isEqualTo: currentUser.uid)
            .getDocuments()
        
        let requests = try snapshot.documents.compactMap { document -> TrustRequest? in
            try document.data(as: TrustRequest.self)
        }
        
        DispatchQueue.main.async {
            self.receivedRequests = requests
        }
        
        return requests
    }
    
    func fetchReceivedRequests(completion: @escaping (Result<[TrustRequest], Error>) -> Void) {
        Task {
            do {
                let requests = try await fetchReceivedRequests()
                DispatchQueue.main.async {
                    completion(.success(requests))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchRequestById(_ requestId: String) async throws -> TrustRequest {
        let document = try await db.collection(requestsCollection).document(requestId).getDocument()
        
        if !document.exists {
            throw NSError(domain: "TrustRequestService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Request not found"])
        }
        
        return try document.data(as: TrustRequest.self)
    }
    
    func fetchRequestById(_ requestId: String, completion: @escaping (Result<TrustRequest, Error>) -> Void) {
        Task {
            do {
                let request = try await fetchRequestById(requestId)
                DispatchQueue.main.async {
                    completion(.success(request))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Update Request Status
    
    func updateRequestStatus(requestId: String, status: TrustRequest.Status) async throws {
        
        try await db.collection(requestsCollection).document(requestId).updateData([
            "status": status.rawValue
        ])
        
        // Update local arrays if needed
        DispatchQueue.main.async {
            self.updateLocalArrays(requestId: requestId, newStatus: status)
        }
    }
    
    func updateRequestStatus(requestId: String, status: TrustRequest.Status, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await updateRequestStatus(requestId: requestId, status: status)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Alternative method signature to match TrustRequestsView expectations
    func updateRequestStatus(requestId: String, newStatus: TrustRequest.Status, completion: @escaping (Result<Void, Error>) -> Void) {
        updateRequestStatus(requestId: requestId, status: newStatus, completion: completion)
    }
    
    // Update requests in the local arrays to maintain UI consistency
    private func updateLocalArrays(requestId: String, newStatus: TrustRequest.Status) {
        if let index = sentRequests.firstIndex(where: { $0.requestId == requestId }) {
            sentRequests[index] = sentRequests[index].withStatus(newStatus)
        }
        
        if let index = receivedRequests.firstIndex(where: { $0.requestId == requestId }) {
            receivedRequests[index] = receivedRequests[index].withStatus(newStatus)
        }
    }
    
    // MARK: - Accept or Decline Requests
    
    func acceptRequest(requestId: String) async throws {
        try await updateRequestStatus(requestId: requestId, status: .accepted)
    }
    
    func acceptRequest(requestId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        updateRequestStatus(requestId: requestId, status: .accepted, completion: completion)
    }
    
    func declineRequest(requestId: String) async throws {
        try await updateRequestStatus(requestId: requestId, status: .declined)
    }
    
    func declineRequest(requestId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        updateRequestStatus(requestId: requestId, status: .declined, completion: completion)
    }
    
    func revokeRequest(requestId: String) async throws {
        try await updateRequestStatus(requestId: requestId, status: .revoked)
    }
    
    func revokeRequest(requestId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        updateRequestStatus(requestId: requestId, status: .revoked, completion: completion)
    }
    
    // MARK: - Listeners
    
    func listenForSentRequestsUpdates() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Remove existing listener if any
        removeListenersForSentRequests()
        
        let listener = db.collection(requestsCollection)
            .whereField("senderId", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else {
                    print("Error listening for sent requests: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                do {
                    let requests = try snapshot.documents.compactMap { document -> TrustRequest? in
                        try document.data(as: TrustRequest.self)
                    }
                    
                    DispatchQueue.main.async {
                        self.sentRequests = requests
                    }
                } catch {
                    print("Error decoding sent requests: \(error.localizedDescription)")
                }
            }
        
        listenerRegistrations.append(listener)
    }
    
    func listenForReceivedRequestsUpdates() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Remove existing listener if any
        removeListenersForReceivedRequests()
        
        let listener = db.collection(requestsCollection)
            .whereField("receiverId", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else {
                    print("Error listening for received requests: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                do {
                    let requests = try snapshot.documents.compactMap { document -> TrustRequest? in
                        try document.data(as: TrustRequest.self)
                    }
                    
                    DispatchQueue.main.async {
                        self.receivedRequests = requests
                    }
                } catch {
                    print("Error decoding received requests: \(error.localizedDescription)")
                }
            }
        
        listenerRegistrations.append(listener)
    }
    
    // Listen for sent requests with specific userId (for TrustRequestsView compatibility)
    func listenForSentRequests(userId: String, completion: @escaping ([TrustRequest]) -> Void) -> ListenerRegistration {
        let listener = db.collection(requestsCollection)
            .whereField("senderId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error listening for sent requests: \(error?.localizedDescription ?? "Unknown error")")
                    completion([])
                    return
                }
                
                do {
                    let requests = try snapshot.documents.compactMap { document -> TrustRequest? in
                        try document.data(as: TrustRequest.self)
                    }
                    
                    DispatchQueue.main.async {
                        // Also update the published property for other UI components
                        if userId == Auth.auth().currentUser?.uid {
                            self.sentRequests = requests
                        }
                        completion(requests)
                    }
                } catch {
                    print("Error decoding sent requests: \(error.localizedDescription)")
                    completion([])
                }
            }
        
        listenerRegistrations.append(listener)
        return listener
    }
    
    // Listen for received requests with specific userId (for TrustRequestsView compatibility)
    func listenForReceivedRequests(userId: String, completion: @escaping ([TrustRequest]) -> Void) -> ListenerRegistration {
        let listener = db.collection(requestsCollection)
            .whereField("receiverId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("Error listening for received requests: \(error?.localizedDescription ?? "Unknown error")")
                    completion([])
                    return
                }
                
                do {
                    let requests = try snapshot.documents.compactMap { document -> TrustRequest? in
                        try document.data(as: TrustRequest.self)
                    }
                    
                    DispatchQueue.main.async {
                        // Also update the published property for other UI components
                        if userId == Auth.auth().currentUser?.uid {
                            self.receivedRequests = requests
                        }
                        completion(requests)
                    }
                } catch {
                    print("Error decoding received requests: \(error.localizedDescription)")
                    completion([])
                }
            }
        
        listenerRegistrations.append(listener)
        return listener
    }
    
    func listenForSpecificRequestUpdates(requestId: String, completion: @escaping (Result<TrustRequest, Error>) -> Void) -> ListenerRegistration {
        let listener = db.collection(requestsCollection)
            .document(requestId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, snapshot.exists else {
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.failure(NSError(domain: "TrustRequestService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Request not found"])))
                    }
                    return
                }
                
                do {
                    let request = try snapshot.data(as: TrustRequest.self)
                    completion(.success(request))
                } catch {
                    completion(.failure(error))
                }
            }
        
        listenerRegistrations.append(listener)
        return listener
    }
    
    // MARK: - Remove Listeners
    
    func removeListenersForSentRequests() {
        // This is a simplified approach. In a more complex app, you might want to
        // track which listeners are for which purpose more specifically.
        removeAllListeners()
    }
    
    func removeListenersForReceivedRequests() {
        // This is a simplified approach. In a more complex app, you might want to
        // track which listeners are for which purpose more specifically.
        removeAllListeners()
    }
    
    func removeListener(_ listener: ListenerRegistration) {
        listener.remove()
        if let index = listenerRegistrations.firstIndex(where: { $0 === listener }) {
            listenerRegistrations.remove(at: index)
        }
    }
    
    func removeAllListeners() {
        for listener in listenerRegistrations {
            listener.remove()
        }
        listenerRegistrations.removeAll()
    }
}

// MARK: - Helpers

extension TrustRequest {
    func asDictionary() throws -> [String: Any] {
        let encoder = Firestore.Encoder()
        return try encoder.encode(self)
    }
}

