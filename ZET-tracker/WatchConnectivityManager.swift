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
    static let shared = WatchConnectivityManager()          // Creating a singleton instance for easy access throughout the app
    @Published var isWatchReachable = false
    
    private override init() {           // init can't be called from outside the class, ensuring that only one instance exists
        super.init()
        setupSession()
    }
    
    private func setupSession() {               // Setting up the WCSession and activating it to start listening for messages from the watch, delegate is the class itself
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    func sendVehiclesToWatch() async {
        guard WCSession.default.activationState == .activated else {        // Check if the session is activated
            print("Session not activated.")
            return
        }
        
        do {
            print("Fetcham vozila...")
            let fetcher = RealTimeFetcher()                             // Fetching vehicles from ZET website
            let vehicles = try await fetcher.fetchVehicles()
            print("Fetched \(vehicles.count) vehicles.")
            
            let encoder = JSONEncoder()                             // Encoding the vehicles data into JSON format to send to the watch
            let jsonData = try encoder.encode(vehicles)
            
            if WCSession.default.isReachable {          // If the watch is reachable (in foreground) send the data, otherwise update the application context with background delivery
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
    func session(_ session: WCSession,                       // Activating session with call in setupSession
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error = error {
            print("Activation failed: \(error)")
        } else {
            print("Session activated!")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {       // If reachability changes, update the variable accordingly, DispatchQueue is used to ensure that UI updates happen on the main thread
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("Watch reachable: \(session.isReachable)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Session inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {           // When the session is deactivated, we need to activate it again to continue receiving messages
        print("Session deactivated")
        session.activate()
    }
    
    func session(_ session: WCSession,                              // Used for receiving requests from the watch
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
