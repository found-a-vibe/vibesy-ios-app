//
//  EnhancedNetworkService.swift
//  Vibesy
//
//  Created by Refactoring Bot on 12/19/24.
//

import Foundation
import Network
import Combine
import os.log

// MARK: - Network Errors
enum NetworkError: LocalizedError, Equatable {
    case noConnection
    case timeout
    case invalidResponse
    case serverError(Int, String?)
    case rateLimitExceeded
    case requestFailed(Error)
    case dataCorrupted
    case authenticationRequired
    case forbidden
    case notFound
    case tooManyRequests
    case internalServerError
    case badGateway
    case serviceUnavailable
    case gatewayTimeout
    
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.noConnection, .noConnection),
             (.timeout, .timeout),
             (.invalidResponse, .invalidResponse),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.dataCorrupted, .dataCorrupted),
             (.authenticationRequired, .authenticationRequired),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.tooManyRequests, .tooManyRequests),
             (.internalServerError, .internalServerError),
             (.badGateway, .badGateway),
             (.serviceUnavailable, .serviceUnavailable),
             (.gatewayTimeout, .gatewayTimeout):
            return true
        case (.serverError(let code1, _), .serverError(let code2, _)):
            return code1 == code2
        case (.requestFailed(let error1), .requestFailed(let error2)):
            return error1.localizedDescription == error2.localizedDescription
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .dataCorrupted:
            return "Response data is corrupted"
        case .authenticationRequired:
            return "Authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .tooManyRequests:
            return "Too many requests. Please slow down"
        case .internalServerError:
            return "Internal server error"
        case .badGateway:
            return "Bad gateway"
        case .serviceUnavailable:
            return "Service temporarily unavailable"
        case .gatewayTimeout:
            return "Gateway timeout"
        }
    }
}

// MARK: - Retry Configuration
struct RetryConfiguration {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let retryableStatusCodes: Set<Int>
    
    static let `default` = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )
    
    static let aggressive = RetryConfiguration(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        backoffMultiplier: 2.5,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )
}

// MARK: - Network Monitor
@MainActor
class NetworkConnectivityMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType? = nil
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                Self.logger.info("Network status changed - Connected: \(self?.isConnected ?? false)")
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
}

// MARK: - Enhanced Network Service
@MainActor
final class EnhancedNetworkService: ObservableObject {
    static let shared = EnhancedNetworkService()
    
    @Published var isOnline: Bool = true
    private let networkMonitor = NetworkConnectivityMonitor()
    
    private let session: URLSession
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "EnhancedNetworkService")
    
    // Offline storage for failed requests
    private var offlineQueue: [OfflineRequest] = []
    private let maxOfflineRequests = 100
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Security configuration
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.httpShouldUsePipelining = false
        config.httpShouldSetCookies = false
        
        self.session = URLSession(configuration: config)
        
        // Observe network connectivity changes
        Task {
            for await isConnected in networkMonitor.$isConnected.values {
                self.isOnline = isConnected
                if isConnected {
                    await processOfflineQueue()
                }
            }
        }
        
        logger.info("EnhancedNetworkService initialized")
    }
    
    // MARK: - Core Network Methods
    
    func performRequest<T: Codable>(
        _ request: URLRequest,
        responseType: T.Type,
        retryConfig: RetryConfiguration = .default
    ) async throws -> T {
        
        // Check connectivity
        guard isOnline else {
            // Store for offline processing if possible
            if request.httpMethod == "GET" {
                storeOfflineRequest(request)
            }
            throw NetworkError.noConnection
        }
        
        return try await performRequestWithRetry(
            request,
            responseType: responseType,
            retryConfig: retryConfig,
            attempt: 0
        )
    }
    
    private func performRequestWithRetry<T: Codable>(
        _ request: URLRequest,
        responseType: T.Type,
        retryConfig: RetryConfiguration,
        attempt: Int
    ) async throws -> T {
        
        do {
            logger.debug("Performing request to: \(request.url?.absoluteString ?? "unknown") (attempt \(attempt + 1))")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle HTTP status codes
            try validateHTTPResponse(httpResponse, data: data)
            
            // Decode response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let result = try decoder.decode(responseType, from: data)
                logger.debug("Request successful for: \(request.url?.absoluteString ?? "unknown")")
                return result
            } catch {
                logger.error("Failed to decode response: \(error.localizedDescription)")
                throw NetworkError.dataCorrupted
            }
            
        } catch let error as NetworkError {
            // Check if we should retry
            if shouldRetry(error: error, attempt: attempt, config: retryConfig) {
                let delay = calculateRetryDelay(attempt: attempt, config: retryConfig)
                logger.info("Retrying request after \(delay)s delay (attempt \(attempt + 1)/\(retryConfig.maxRetries))")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                return try await performRequestWithRetry(
                    request,
                    responseType: responseType,
                    retryConfig: retryConfig,
                    attempt: attempt + 1
                )
            } else {
                throw error
            }
        } catch {
            let networkError = NetworkError.requestFailed(error)
            
            if shouldRetry(error: networkError, attempt: attempt, config: retryConfig) {
                let delay = calculateRetryDelay(attempt: attempt, config: retryConfig)
                logger.info("Retrying request after \(delay)s delay due to: \(error.localizedDescription)")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                return try await performRequestWithRetry(
                    request,
                    responseType: responseType,
                    retryConfig: retryConfig,
                    attempt: attempt + 1
                )
            } else {
                throw networkError
            }
        }
    }
    
    // MARK: - Response Validation
    
    private func validateHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        let statusCode = response.statusCode
        
        switch statusCode {
        case 200...299:
            // Success
            return
        case 400:
            throw NetworkError.requestFailed(NSError(domain: "HTTP", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Bad Request"]))
        case 401:
            throw NetworkError.authenticationRequired
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 408:
            throw NetworkError.timeout
        case 429:
            throw NetworkError.tooManyRequests
        case 500:
            throw NetworkError.internalServerError
        case 502:
            throw NetworkError.badGateway
        case 503:
            throw NetworkError.serviceUnavailable
        case 504:
            throw NetworkError.gatewayTimeout
        default:
            let message = parseErrorMessage(from: data)
            throw NetworkError.serverError(statusCode, message)
        }
    }
    
    private func parseErrorMessage(from data: Data) -> String? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String ?? json["error"] as? String {
                return message
            }
        } catch {
            // If JSON parsing fails, try to get string representation
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    // MARK: - Retry Logic
    
    private func shouldRetry(error: NetworkError, attempt: Int, config: RetryConfiguration) -> Bool {
        guard attempt < config.maxRetries else { return false }
        
        switch error {
        case .noConnection, .timeout, .tooManyRequests, .internalServerError, .badGateway, .serviceUnavailable, .gatewayTimeout:
            return true
        case .serverError(let code, _):
            return config.retryableStatusCodes.contains(code)
        case .requestFailed:
            return true
        default:
            return false
        }
    }
    
    private func calculateRetryDelay(attempt: Int, config: RetryConfiguration) -> TimeInterval {
        let exponentialDelay = config.baseDelay * pow(config.backoffMultiplier, Double(attempt))
        let jitteredDelay = exponentialDelay * (0.5 + Double.random(in: 0...0.5)) // Add jitter
        return min(jitteredDelay, config.maxDelay)
    }
    
    // MARK: - Offline Support
    
    private struct OfflineRequest {
        let request: URLRequest
        let timestamp: Date
        let retryCount: Int
    }
    
    private func storeOfflineRequest(_ request: URLRequest) {
        guard offlineQueue.count < maxOfflineRequests else {
            logger.warning("Offline queue is full, dropping oldest request")
            offlineQueue.removeFirst()
        }
        
        let offlineRequest = OfflineRequest(
            request: request,
            timestamp: Date(),
            retryCount: 0
        )
        
        offlineQueue.append(offlineRequest)
        logger.info("Stored request for offline processing: \(request.url?.absoluteString ?? "unknown")")
    }
    
    private func processOfflineQueue() async {
        guard !offlineQueue.isEmpty else { return }
        
        logger.info("Processing \(offlineQueue.count) offline requests")
        
        var processedIndices: [Int] = []
        
        for (index, offlineRequest) in offlineQueue.enumerated() {
            do {
                // Try to perform the request
                let (_, response) = try await session.data(for: offlineRequest.request)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode < 400 {
                    processedIndices.append(index)
                    logger.debug("Successfully processed offline request: \(offlineRequest.request.url?.absoluteString ?? "unknown")")
                }
            } catch {
                logger.error("Failed to process offline request: \(error.localizedDescription)")
                
                // Remove old failed requests
                let hourAgo = Date().addingTimeInterval(-3600)
                if offlineRequest.timestamp < hourAgo {
                    processedIndices.append(index)
                }
            }
        }
        
        // Remove processed requests
        for index in processedIndices.sorted(by: >) {
            offlineQueue.remove(at: index)
        }
    }
    
    // MARK: - Convenience Methods
    
    func get<T: Codable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type,
        retryConfig: RetryConfiguration = .default
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return try await performRequest(request, responseType: responseType, retryConfig: retryConfig)
    }
    
    func post<T: Codable>(
        url: URL,
        body: Data,
        headers: [String: String] = [:],
        responseType: T.Type,
        retryConfig: RetryConfiguration = .default
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if headers["Content-Type"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return try await performRequest(request, responseType: responseType, retryConfig: retryConfig)
    }
    
    func put<T: Codable>(
        url: URL,
        body: Data,
        headers: [String: String] = [:],
        responseType: T.Type,
        retryConfig: RetryConfiguration = .default
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = body
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if headers["Content-Type"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return try await performRequest(request, responseType: responseType, retryConfig: retryConfig)
    }
    
    func delete<T: Codable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type,
        retryConfig: RetryConfiguration = .default
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return try await performRequest(request, responseType: responseType, retryConfig: retryConfig)
    }
    
    // MARK: - Health Check
    
    func performHealthCheck(url: URL) async throws -> Bool {
        do {
            let request = URLRequest(url: url)
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 400
            }
            return false
        } catch {
            logger.error("Health check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        offlineQueue.removeAll()
        logger.info("EnhancedNetworkService cleanup completed")
    }
    
    // MARK: - Statistics
    
    var offlineQueueCount: Int {
        return offlineQueue.count
    }
}

// MARK: - Network Service Extensions

extension EnhancedNetworkService {
    // Firebase-specific convenience methods
    
    func performFirebaseRequest<T: Codable>(
        url: URL,
        method: String = "GET",
        body: [String: Any]? = nil,
        responseType: T.Type,
        requiresAuth: Bool = true
    ) async throws -> T {
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add common headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        // Add auth token if required
        if requiresAuth {
            do {
                if let token = try EnhancedSecurityService.shared.getAuthToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
            } catch {
                logger.error("Failed to get auth token: \(error.localizedDescription)")
                if requiresAuth {
                    throw NetworkError.authenticationRequired
                }
            }
        }
        
        // Add body if provided
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw NetworkError.requestFailed(error)
            }
        }
        
        return try await performRequest(
            request,
            responseType: responseType,
            retryConfig: .default
        )
    }
}