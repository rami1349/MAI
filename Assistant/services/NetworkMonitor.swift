//
//  NetworkMonitor.swift
//  Assistant
//
//  Created by Ramiro  on 2/9/26.
//  Lightweight connectivity observer using NWPathMonitor.
//  Publishes a single `isConnected` bool for UI consumption.


import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published private(set) var isConnected: Bool = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let connected = path.status == .satisfied
                // Only publish when the value actually changes
                if self?.isConnected != connected {
                    self?.isConnected = connected
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
