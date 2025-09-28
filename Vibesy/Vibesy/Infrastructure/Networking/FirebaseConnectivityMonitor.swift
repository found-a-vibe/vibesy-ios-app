//
//  FirebaseConnectivityMonitor.swift
//  Vibesy
//
//  Created by Refactoring Bot on 12/19/24.
//

import Foundation
import FirebaseFirestore
import Combine
import os.log

// MARK: - Firebase Connection State
enum FirebaseConnectionState {
    case connected
    case disconnected
    case connecting
    case error(Error)
}

// MARK: - Firebase Connectivity Monitor
@MainActor
final class FirebaseConnectivityMonitor: ObservableObject {
    static let shared = FirebaseConnectivityMonitor()
    
    @Published var connectionState: FirebaseConnectionState = .disconnected
    @Published var isOnline: Bool = false
    @Published var lastSyncTime: Date? = nil
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "FirebaseConnectivity")
    
    private var connectionListener: ListenerRegistration?
    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 30 // 30 seconds
    
    // Offline queue for failed operations
    private var offlineOperations: [OfflineOperation] = []
    private let maxOfflineOperations = 50
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        // Cleanup is handled by stopMonitoring() method
        // Can't access non-Sendable properties from nonisolated deinit
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // Listen to connection state changes
        connectionListener = db.collection("connectivity-test")
            .limit(to: 1)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.handleConnectionStateChange(snapshot: snapshot, error: error)
                }
            }
        
        // Start periodic health checks
        startHealthChecks()
        
        logger.info("Firebase connectivity monitoring started")
    }
    
    private func stopMonitoring() {
        connectionListener?.remove()
        connectionListener = nil
        
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        
        logger.info("Firebase connectivity monitoring stopped")
    }
    
    private func handleConnectionStateChange(snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            logger.error("Firebase connection error: \(error.localizedDescription)")
            updateConnectionState(.error(error))
            return
        }
        
        guard let snapshot = snapshot else {
            updateConnectionState(.disconnected)
            return
        }
        
        if snapshot.metadata.isFromCache {
            if !isOnline {
                updateConnectionState(.disconnected)
            }
        } else {
            updateConnectionState(.connected)
            lastSyncTime = Date()
            
            // Process offline queue when connection is restored
            Task {
                await processOfflineOperations()
            }
        }
    }
    
    private func updateConnectionState(_ newState: FirebaseConnectionState) {
        connectionState = newState
        
        switch newState {
        case .connected:
            isOnline = true
            logger.info("Firebase connected")
        case .disconnected, .error:
            isOnline = false
            logger.warning("Firebase disconnected")
        case .connecting:
            logger.info("Firebase connecting...")
        }
    }
    
    // MARK: - Health Checks
    
    private func startHealthChecks() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performHealthCheck()
            }
        }
    }
    
    private func performHealthCheck() async {
        do {
            updateConnectionState(.connecting)
            
            // Try to read a small document
            _ = try await db.collection("health-check")
                .limit(to: 1)
                .getDocuments(source: .server)
            
            updateConnectionState(.connected)
            lastSyncTime = Date()
            
        } catch {
            logger.error("Health check failed: \(error.localizedDescription)")
            updateConnectionState(.error(error))
        }
    }
    
    // MARK: - Offline Operation Management
    
    private struct OfflineOperation {
        let id: UUID
        let operation: () async throws -> Void
        let timestamp: Date
        let retryCount: Int
        let maxRetries: Int
        
        init(operation: @escaping () async throws -> Void, maxRetries: Int = 3) {
            self.id = UUID()
            self.operation = operation
            self.timestamp = Date()
            self.retryCount = 0
            self.maxRetries = maxRetries
        }
        
        private init(id: UUID, operation: @escaping () async throws -> Void, timestamp: Date, retryCount: Int, maxRetries: Int) {
            self.id = id
            self.operation = operation
            self.timestamp = timestamp
            self.retryCount = retryCount
            self.maxRetries = maxRetries
        }
        
        func withIncrementedRetry() -> OfflineOperation {
            return OfflineOperation(
                id: self.id,
                operation: self.operation,
                timestamp: self.timestamp,
                retryCount: self.retryCount + 1,
                maxRetries: self.maxRetries
            )
        }
        
        var shouldRetry: Bool {
            return retryCount < maxRetries
        }
    }
    
    func queueOfflineOperation(_ operation: @escaping () async throws -> Void) {
        if offlineOperations.count >= maxOfflineOperations {
            logger.warning("Offline operations queue is full, dropping oldest operation")
            offlineOperations.removeFirst()
        }
        
        let offlineOp = OfflineOperation(operation: operation)
        offlineOperations.append(offlineOp)
        
        logger.info("Queued offline operation (total: \(self.offlineOperations.count))")
    }
    
    private func processOfflineOperations() async {
        guard !offlineOperations.isEmpty else { return }
        
        logger.info("Processing \(self.offlineOperations.count) offline operations")
        
        var processedIndices: [Int] = []
        var retriedOperations: [OfflineOperation] = []
        
        for (index, operation) in offlineOperations.enumerated() {
            do {
                try await operation.operation()
                processedIndices.append(index)
                logger.debug("Successfully processed offline operation")
                
            } catch {
                logger.error("Failed to process offline operation: \(error.localizedDescription)")
                
                if operation.shouldRetry {
                    retriedOperations.append(operation.withIncrementedRetry())
                } else {
                    processedIndices.append(index)
                    logger.warning("Dropping offline operation after max retries")
                }
            }
        }
        
        // Remove processed operations
        for index in processedIndices.sorted(by: >) {
            offlineOperations.remove(at: index)
        }
        
        // Add retried operations back to the queue
        offlineOperations.append(contentsOf: retriedOperations)
        
        // Remove operations older than 1 hour
        let oneHourAgo = Date().addingTimeInterval(-3600)
        offlineOperations = offlineOperations.filter { $0.timestamp >= oneHourAgo }
    }
    
    // MARK: - Manual Connection Management
    
    func forceReconnect() {
        logger.info("Forcing Firebase reconnection")
        updateConnectionState(.connecting)
        
        Task {
            // Disable and re-enable network
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                db.disableNetwork { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    // Re-enable after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.db.enableNetwork { error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                }
            }
            
            await performHealthCheck()
        }
    }
    
    func goOffline() {
        logger.info("Going offline manually")
        db.disableNetwork { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.logger.error("Failed to go offline: \(error.localizedDescription)")
                } else {
                    self?.updateConnectionState(.disconnected)
                }
            }
        }
    }
    
    func goOnline() {
        logger.info("Going online manually")
        updateConnectionState(.connecting)
        
        db.enableNetwork { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.logger.error("Failed to go online: \(error.localizedDescription)")
                    self?.updateConnectionState(.error(error))
                } else {
                    await self?.performHealthCheck()
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    var offlineOperationsCount: Int {
        return offlineOperations.count
    }
    
    var connectionUptime: TimeInterval? {
        guard let lastSync = lastSyncTime else { return nil }
        return Date().timeIntervalSince(lastSync)
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopMonitoring()
        offlineOperations.removeAll()
        logger.info("Firebase connectivity monitor cleanup completed")
    }
}

// MARK: - Extensions

extension FirebaseConnectivityMonitor {
    // Convenience method for performing operations with offline support
    func performOperationWithOfflineSupport<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        if isOnline {
            do {
                return try await operation()
            } catch {
                // Queue for offline processing if it's a write operation
                queueOfflineOperation {
                    _ = try await operation()
                }
                throw error
            }
        } else {
            // Queue the operation for later execution
            queueOfflineOperation {
                _ = try await operation()
            }
            throw NetworkError.noConnection
        }
    }
}