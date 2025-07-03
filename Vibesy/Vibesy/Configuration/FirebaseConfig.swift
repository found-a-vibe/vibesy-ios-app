//
//  FirebaseConfig.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//
import Firebase

enum Environment {
    case development
    case production
}

enum FirebaseConfigError: Error {
    case missingPlistFile(fileName: String)
    case optionsFailedFromPlistPath(plistPath: String)
}

public class FirebaseConfig {
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
            throw FirebaseConfigError.optionsFailedFromPlistPath(plistPath: plistPath)
        }
        
        FirebaseApp.configure(options: options)
    }
}
