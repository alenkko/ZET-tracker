//
//  WatchConnectivityManager.swift
//  ZET-tracker
//
//  Created by Alen Jurina on 15.02.2026..
//

import Foundation
import WatchConnectivity
internal import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    @Published var isWatchReachable = false
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    func sendVehiclesToWatch() async {
        guard WCSession.default.activationState == .activated else {
            print("Session not activated.")
            return
        }
        
        do {
            print("Fetcham vozila...")
            let fetcher = RealTimeFetcher()
            let vehicles = try await fetcher.fetchVehicles()
            print("Fetched \(vehicles.count) vehicles.")
            
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(vehicles)
            
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["vehicles": jsonData],
                    replyHandler: { reply in
                        print("Watch answer: \(reply)")
                    },
                    errorHandler: { error in
                        print("Error: \(error)")
                    }
                )
            } else {
                print("Background send...")
                try WCSession.default.updateApplicationContext(["vehicles": jsonData])
            }
            
        } catch {
            print("Error: \(error)")
        }
    }
    
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            print("Activation failed: \(error)")
        } else {
            print("Session activated!")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("Watch reachable: \(session.isReachable)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Session inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("Session deactivated")
        session.activate()
    }
    
    func session(_ session: WCSession,
                     didReceiveMessage message: [String : Any],
                     replyHandler: @escaping ([String : Any]) -> Void) {
                    
        if message["request"] as? String == "fetchVehicles" {
            Task {
                await sendVehiclesToWatch()
                replyHandler(["status": "sent"])
            }
        }
    }
}
