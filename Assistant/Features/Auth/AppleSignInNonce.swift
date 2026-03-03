//
//  AppleSignInNonce.swift
//  Assistant
//
//  Created by Ramiro  on 2/1/26.
//


//
//  AppleSignInNonce.swift
//  FamilyHub
//
//  Helper utilities for Sign in with Apple secure nonce generation
//

import Foundation
import CryptoKit

/// Generates a random nonce string for Apple Sign-In security
/// The nonce is used to prevent replay attacks
enum AppleSignInNonce {
    
    /// Generates a cryptographically secure random nonce
    /// - Parameter length: The length of the nonce string (default: 32)
    /// - Returns: A random alphanumeric string
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    /// Hashes the nonce using SHA256 for Apple Sign-In
    /// - Parameter input: The raw nonce string
    /// - Returns: SHA256 hash of the input as a hex string
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}