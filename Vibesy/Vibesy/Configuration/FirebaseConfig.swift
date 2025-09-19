//
//  FirebaseConfig.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//
import Firebase
import FirebaseFirestore
import os.log

enum Environment {
    case development
    case production
}

enum FirebaseConfigError: Error {
    case missingPlistFile(fileName: String)
    case optionsFailedFromPlistPath(plistPath: String)
    case firestoreConfigurationFailed
    case offlinePersistenceFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .missingPlistFile(let fileName):
            return "Missing Firebase configuration file: \(fileName).plist"
        case .optionsFailedFromPlistPath(let path):
            return "Failed to create Firebase options from plist: \(path)"
        case .firestoreConfigurationFailed:
            return "Failed to configure Firestore settings"
        case .offlinePersistenceFailed(let error):
            return "Failed to enable offline persistence: \(error.localizedDescription)"
        }
    }
}

public class FirebaseConfig {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "FirebaseConfig")
    
    static public func configure() throws {
        let environment: Environment = {
            #if DEBUG
            return .development
            #else
            return .production
            #endif
        }()
        
        let plistFileName: String
        switch environment {
        case .development:
            plistFileName = "GoogleServiceNonProd-Info"
        case .production:
            plistFileName = "GoogleServiceProd-Info"
        }
        
        guard let plistPath = Bundle.main.path(forResource: plistFileName, ofType: "plist") else {
            throw FirebaseConfigError.missingPlistFile(fileName: plistFileName)
        }
        
        guard let options = FirebaseOptions(contentsOfFile: plistPath) else {
            logger.error("Failed to create Firebase options from plist: \(plistPath)")
            throw FirebaseConfigError.optionsFailedFromPlistPath(plistPath: plistPath)
        }
        
        // Configure Firebase
        FirebaseApp.configure(options: options)
        logger.info("Firebase configured for environment: \(environment)")
        
        // Configure Firestore settings
        try configureFirestore()
        
        logger.info("Firebase configuration completed successfully")
    }
    
    // MARK: - Firestore Configuration
    private static func configureFirestore() throws {
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        
        // Enable offline persistence
        settings.isPersistenceEnabled = true
        
        // Set cache size (100 MB)
        settings.cacheSizeBytes = 100 * 1024 * 1024
        
        // Configure host and SSL
        #if DEBUG
        // In development, we might want to use local emulator
        // settings.host = "localhost:8080"
        // settings.isSSLEnabled = false
        #endif
        
        do {
            db.settings = settings
            logger.info("Firestore configured with offline persistence enabled")
            
            // Enable network for initial sync
            enableFirestoreNetwork()
            
        } catch {
            logger.error("Failed to configure Firestore: \(error.localizedDescription)")
            throw FirebaseConfigError.offlinePersistenceFailed(error)
        }
    }
    
    // MARK: - Network Management
    static func enableFirestoreNetwork() {
        let db = Firestore.firestore()
        db.enableNetwork { error in
            if let error = error {
                logger.error("Failed to enable Firestore network: \(error.localizedDescription)")
            } else {
                logger.info("Firestore network enabled")
            }
        }
    }
    
    static func disableFirestoreNetwork() {
        let db = Firestore.firestore()
        db.disableNetwork { error in
            if let error = error {
                logger.error("Failed to disable Firestore network: \(error.localizedDescription)")
            } else {
                logger.info("Firestore network disabled")
            }
        }
    }
    
    // MARK: - Cache Management
    static func clearFirestoreCache() async throws {
        let db = Firestore.firestore()
        
        do {
            try await db.clearPersistence()
            logger.info("Firestore cache cleared")
        } catch {
            logger.error("Failed to clear Firestore cache: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Health Check
    static func performHealthCheck() async -> Bool {
        let db = Firestore.firestore()
        
        do {
            // Try to perform a simple read operation
            _ = try await db.collection("health").limit(to: 1).getDocuments()
            logger.info("Firebase health check passed")
            return true
        } catch {
            logger.error("Firebase health check failed: \(error.localizedDescription)")
            return false
        }
    }
}
