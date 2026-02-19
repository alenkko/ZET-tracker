//
//  WatchDataReciever.swift
//  ZET-tracker Watch App
//
//  Created by Alen Jurina on 15.02.2026..
//

import Foundation
import WatchConnectivity
import Combine

class WatchDataReceiver: NSObject, ObservableObject {
    static let shared = WatchDataReceiver()     // Creating a singleton instance
    
    @Published var vehicles: [VehicleData] = []
    @Published var lastUpdateTime: Date?
    @Published var isConnected = false
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {                      // Setting up the session
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported")
            return
        }
        
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    func requestVehiclesFromPhone() {                                   // Making a request for fetching vehicles
        guard WCSession.default.activationState == .activated else {
            print("Session not activated")
            return
        }
        
        guard WCSession.default.isReachable else {
            print("iPhone not reachable")
            return
        }
        
        print("Sending request to iPhone...")
        
        WCSession.default.sendMessage(                  // Sending a message to the iPhone
            ["request": "fetchVehicles"],
            replyHandler: { reply in
                print("iPhone replied: \(reply)")
            },
            errorHandler: { error in
                print("Error: \(error)")
            }
        )
    }
    
    private func decodeAndUpdateVehicles(_ data: Data) {                // Decoding the received data and updating the vehicles list on the watch
        do {
            let decoder = JSONDecoder()
            let decodedVehicles = try decoder.decode([VehicleData].self, from: data)
            
            DispatchQueue.main.async {
                self.vehicles = decodedVehicles
                self.lastUpdateTime = Date()
                print("Loaded \(decodedVehicles.count) vehicles")
            }
        } catch {
            print("Decoding failed: \(error)")
        }
    }
    
    
}

extension WatchDataReceiver: WCSessionDelegate {            // Two main functions are the same as on iOS part
    func session(_ session: WCSession,
             activationDidCompleteWith activationState: WCSessionActivationState,
             error: Error?) {
        if let error = error {
            print("Activation failed: \(error)")
        } else {
            print("Session activated!")
            DispatchQueue.main.async {
                self.isConnected = true
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
            print("iPhone reachable: \(session.isReachable)")
        }
    }
    
    func session(_ session: WCSession,                                      // Receiving messages with reply handler, used for fetching vehicles on demand from iPhone
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message WITH reply handler: \(message.keys)")
        
        if let vehiclesData = message["vehicles"] as? Data {
            decodeAndUpdateVehicles(vehiclesData)
            
            replyHandler(["status": "received", "count": self.vehicles.count])
        } else {
            replyHandler(["status": "error", "message": "No vehicles data"])
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {     // Receiving messages without reply handler
        print("Received message: \(message.keys)")
        
        if let vehiclesData = message["vehicles"] as? Data {
            decodeAndUpdateVehicles(vehiclesData)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {           // Receiving background updates through context
        print("Received background update.")
        
        if let vehiclesData = applicationContext["vehicles"] as? Data {
            decodeAndUpdateVehicles(vehiclesData)
        }
    }
    
}
