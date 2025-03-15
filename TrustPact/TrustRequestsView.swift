import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct TrustRequestsView: View {
    @ObservedObject private var viewModel = TrustRequestViewModel()
    @State private var showingNewRequestSheet = false
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TabView(selection: $selectedTab) {
                    receivedRequestsView
                        .tabItem {
                            Label("Received", systemImage: "tray.and.arrow.down")
                        }
                        .tag(0)
                    
                    sentRequestsView
                        .tabItem {
                            Label("Sent", systemImage: "tray.and.arrow.up")
                        }
                        .tag(1)
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text(alertTitle),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .navigationTitle("Trust Requests")
            .navigationBarItems(trailing:
                Button(action: {
                    showingNewRequestSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            )
            .sheet(isPresented: $showingNewRequestSheet) {
                NewTrustRequestView(isPresented: $showingNewRequestSheet, onRequestCreated: { result in
                    switch result {
                    case .success:
                        showAlert(title: "Success", message: "Trust request sent successfully")
                    case .failure(let error):
                        showAlert(title: "Error", message: error.localizedDescription)
                    }
                })
            }
            .onAppear {
                viewModel.loadRequests()
            }
        }
    }
    
    var receivedRequestsView: some View {
        List {
            if viewModel.isLoading {
                ProgressView("Loading requests...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else if viewModel.receivedRequests.isEmpty {
                Text("No received requests")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.receivedRequests) { request in
                    ReceivedRequestRow(request: request, onStatusChange: { newStatus in
                        viewModel.updateRequestStatus(request: request, newStatus: newStatus) { result in
                            if case .failure(let error) = result {
                                showAlert(title: "Error", message: error.localizedDescription)
                            }
                        }
                    })
                }
            }
        }
        .refreshable {
            viewModel.loadRequests()
        }
    }
    
    var sentRequestsView: some View {
        List {
            if viewModel.isLoading {
                ProgressView("Loading requests...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else if viewModel.sentRequests.isEmpty {
                Text("No sent requests")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.sentRequests) { request in
                    SentRequestRow(request: request, onRevoke: {
                        viewModel.updateRequestStatus(request: request, newStatus: .revoked) { result in
                            if case .failure(let error) = result {
                                showAlert(title: "Error", message: error.localizedDescription)
                            }
                        }
                    })
                }
            }
        }
        .refreshable {
            viewModel.loadRequests()
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

struct ReceivedRequestRow: View {
    let request: TrustRequest
    let onStatusChange: (TrustRequest.Status) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From: \(request.senderId)")
                .font(.headline)
            
            Text("Requested: \(formattedDate(request.timestamp))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let expiration = request.expiration {
                Text("Expires: \(formattedDate(expiration))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Spacer()
                
                if request.status == .pending {
                    Button("Accept") {
                        onStatusChange(.accepted)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button("Decline") {
                        onStatusChange(.declined)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                } else {
                    StatusBadge(status: request.status)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SentRequestRow: View {
    let request: TrustRequest
    let onRevoke: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To: \(request.receiverId)")
                .font(.headline)
            
            Text("Sent: \(formattedDate(request.timestamp))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let expiration = request.expiration {
                Text("Expires: \(formattedDate(expiration))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Spacer()
                
                StatusBadge(status: request.status)
                
                if request.status == .pending {
                    Button("Revoke") {
                        onRevoke()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: TrustRequest.Status
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
    
    var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .declined:
            return .red
        case .revoked:
            return .gray
        }
    }
}

struct NewTrustRequestView: View {
    @Binding var isPresented: Bool
    let onRequestCreated: (Result<Void, Error>) -> Void
    
    @State private var receiverId = ""
    @State private var expirationDays = 1
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipient")) {
                    TextField("User ID", text: $receiverId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Expiration")) {
                    Stepper("Expires in \(expirationDays) day\(expirationDays == 1 ? "" : "s")", value: $expirationDays, in: 1...30)
                }
                
                Section {
                    Button(action: createRequest) {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Send Trust Request")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(receiverId.isEmpty || isCreating)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("New Trust Request")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
    
    private func createRequest() {
        guard !receiverId.isEmpty else { return }
        
        isCreating = true
        
        let expiration = Calendar.current.date(byAdding: .day, value: expirationDays, to: Date())
        
        let service = TrustRequestService.shared
        service.createRequest(
            receiverId: receiverId,
            expiration: expiration
        ) { result in
            isCreating = false
            onRequestCreated(result)
            if case .success = result {
                isPresented = false
            }
        }
    }
}

class TrustRequestViewModel: ObservableObject {
    @Published var sentRequests: [TrustRequest] = []
    @Published var receivedRequests: [TrustRequest] = []
    @Published var isLoading = false
    
    private let service = TrustRequestService.shared
    private var listenerRegistrations: [ListenerRegistration] = []
    
    deinit {
        // Remove listeners when view model is deallocated
        for registration in listenerRegistrations {
            registration.remove()
        }
    }
    
    func loadRequests() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        isLoading = true
        
        // Remove any existing listeners
        for registration in listenerRegistrations {
            registration.remove()
        }
        listenerRegistrations.removeAll()
        
        // Add listener for sent requests
        let sentListener = service.listenForSentRequests(userId: userId) { [weak self] requests in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.sentRequests = requests
            }
        }
        
        // Add listener for received requests
        let receivedListener = service.listenForReceivedRequests(userId: userId) { [weak self] requests in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.receivedRequests = requests
            }
        }
        
        // Store listener registrations
        if let sentListener = sentListener {
            listenerRegistrations.append(sentListener)
        }
        
        if let receivedListener = receivedListener {
            listenerRegistrations.append(receivedListener)
        }
    }
    
    func updateRequestStatus(request: TrustRequest, newStatus: TrustRequest.Status, completion: @escaping (Result<Void, Error>) -> Void) {
        service.updateRequestStatus(requestId: request.requestId, status: newStatus, completion: completion)
    }
}

struct TrustRequestsView_Previews: PreviewProvider {
    static var previews: some View {
        TrustRequestsView()
    }
}

