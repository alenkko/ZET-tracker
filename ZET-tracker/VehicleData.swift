//
//  VehicleData.swift
//  ZET-tracker
//
//  Created by Alen Jurina on 15.02.2026..
//
import Foundation

struct VehicleData: Identifiable, Sendable, Codable {   // Creating a VehicleData struct for storing information about each vehicle
    let id: String
    let entityId: String
    let routeId: String
    let tripId: String
    let startDate: String
    let latitude: Double
    let longitude: Double
    let timestamp: UInt64
    let destination: String?
    
    var lastUpdateDate: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
    
    var isTram: Bool {
        if let number = Int(routeId) {
            return number >= 1 && number <= 17
        }
        return false
    }
    
    var color: String {
        isTram ? "blue" : "red"
    }
}

extension VehicleData {
    
    static func mock(
        routeId: String,
        latitude: Double,
        longitude: Double,
        destination: String? = nil
    ) -> VehicleData {
        VehicleData(
            id: UUID().uuidString,
            entityId: UUID().uuidString,
            routeId: routeId,
            tripId: "mockTrip",
            startDate: "20260215",
            latitude: latitude,
            longitude: longitude,
            timestamp: UInt64(Date().timeIntervalSince1970),
            destination: destination
        )
    }
    
    static func mockZagrebCluster() -> [VehicleData] {
        let centerLat = 45.8150
        let centerLon = 15.9819
        
        return [
            .mock(routeId: "6", latitude: centerLat, longitude: centerLon, destination: "Glavni kolodvor"),
            .mock(routeId: "11", latitude: centerLat + 0.01, longitude: centerLon - 0.01, destination: "Kvaternikov trg"),
            .mock(routeId: "17", latitude: centerLat - 0.008, longitude: centerLon + 0.012, destination: "Dubrava"),
            .mock(routeId: "109", latitude: centerLat + 0.015, longitude: centerLon + 0.005, destination: "Savski most"),
            .mock(routeId: "220", latitude: centerLat - 0.012, longitude: centerLon - 0.006, destination: "Črnomerec")
        ]
    }
}
