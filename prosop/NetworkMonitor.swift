//
//  NetworkMonitor.swift
//  Prosop
//
//  Created by Arvat Vladimir on 15.03.2026.
//

import Foundation
import Network
import Combine

/// Monitors network connectivity status and quality
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false
    
    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
                
                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wiredEthernet
                } else {
                    self.connectionType = .unknown
                }
                
                #if DEBUG
                print("🌐 Network Status:")
                print("   Connected: \(self.isConnected)")
                print("   Type: \(self.connectionType)")
                print("   Expensive: \(self.isExpensive)")
                print("   Constrained: \(path.isConstrained)")
                #endif
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Check if network is available for AI requests
    var isNetworkAvailableForAI: Bool {
        return isConnected
    }
    
    /// Get a user-friendly description of the network issue
    var networkIssueDescription: String {
        if !isConnected {
            return "No internet connection detected. Please check your network settings and try again."
        } else if isExpensive && connectionType == .cellular {
            return "You're on a cellular connection. AI features may use mobile data."
        } else {
            return "Network connection appears unstable. Please try again."
        }
    }
}
