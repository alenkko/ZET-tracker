//
//  RealTimeZET.swift
//  ZET tracker
//
//  Created by Alen Jurina on 29.01.2026..
//
import Foundation
import SwiftProtobuf
import ZIPFoundation

final class RealTimeFetcher {
    
    private let url = URL(string: "https://www.zet.hr/gtfs-rt-protobuf")!
    private let url2 = URL(string: "https://www.zet.hr/gtfs-scheduled/latest")!
    
    func fetch() async {                // Debug function for GTFS feed
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
            
            print("Ukupno entiteta: \(feed.entity.count)")
            for entity in feed.entity {
                let vehiclePosition = entity.vehicle
                let descriptor = vehiclePosition.vehicle
                let id = descriptor.id
                let tripId = vehiclePosition.trip.tripID
                let routeId = vehiclePosition.trip.routeID
                let lat = vehiclePosition.position.latitude
                let lon = vehiclePosition.position.longitude
                
                if lat == 0.0 && lon == 0.0 { continue }
                
                print("Vozilo \(id) na ruti \(routeId) (trip \(tripId)) se nalazi na (\(lat), \(lon))")
            }
            
        } catch {
            print("Greška: \(error)")
        }
    }
    
    func fetchVehicles() async throws -> [VehicleData] {
        let (data, _) = try await URLSession.shared.data(from: url)
        let feed = try TransitRealtime_FeedMessage(serializedBytes: data)           // Parsing the GTFS feed message with helper file created from proto + SwiftProtobuf library
        
        let tripDestinations = try await fetchGTFSStatic()              // Getting pairs of trip_id and destination
        
        var vehicles: [VehicleData] = []
        
        for entity in feed.entity {
            guard entity.hasVehicle else { continue }
            let vehicle = entity.vehicle
            
            guard vehicle.hasPosition else { continue }
            
            let lat = vehicle.position.latitude
            let lon = vehicle.position.longitude
            
            guard lat != 0.0 || lon != 0.0 else { continue }
            
            let tripId = vehicle.hasTrip ? vehicle.trip.tripID : ""
            var destination: String?
            let parts = tripId.split(separator: "_")
            if parts.count == 5 {
                let key = "\(parts[2])_\(parts[3])_\(parts[4])"
                destination = tripDestinations[key]
            }
            
            let vehicleData = VehicleData(
                id: vehicle.hasVehicle ? vehicle.vehicle.id : "N/A",
                entityId: entity.id,
                routeId: vehicle.hasTrip ? vehicle.trip.routeID : "N/A",
                tripId: vehicle.hasTrip ? vehicle.trip.tripID : "N/A",
                startDate: vehicle.hasTrip ? vehicle.trip.startDate : "",
                latitude: Double(lat),
                longitude: Double(lon),
                timestamp: vehicle.hasTimestamp ? vehicle.timestamp : 0,
                destination: destination
            )
            
            vehicles.append(vehicleData)
        }
        
        return vehicles
    }
    
    func fetchTrams() async throws -> [VehicleData] {           // Helper functions not used in code right now
        let allVehicles = try await fetchVehicles()
        return allVehicles.filter { $0.isTram }
    }
    
    func fetchBuses() async throws -> [VehicleData] {
        let allVehicles = try await fetchVehicles()
        return allVehicles.filter { !$0.isTram }
    }
    
    private func fetchGTFSStatic() async throws -> [String: String] {       // Fetching GTFS static data from ZIP
        let (data, _) = try await URLSession.shared.data(from: url2)
        
        var tripIdToDestination: [String: String] = [:]                     // I wanted to show vehicle destination under vehicle marker on the map
        
        let archive = try Archive(data: data, accessMode: .read)            // Open ZIP archive
        
        if let entry = archive["trips.txt"] {           // Find the "trips.txt" file in the archive
            var csvData = Data()
            _ = try archive.extract(entry, consumer: { csvData.append($0) })            // Storing data from trips in csvData
            
            if let csvString = String(data: csvData, encoding: .utf8) {         // Bytes in String
                let lines = csvString.components(separatedBy: .newlines)        // Separating lines
                guard let header = lines.first else { return [:] }          // Getting header indices
                
                let headerColumns = parseCSVLine(header)
                guard let tripIdIndex = headerColumns.firstIndex(of: "trip_id"),
                      let headsignIndex = headerColumns.firstIndex(of: "trip_headsign") else { return [:] }
                
                for line in lines.dropFirst() {                 // For every remaining line except headers
                    guard !line.isEmpty else { continue }
                    let columns = parseCSVLine(line)
                    if columns.count > max(tripIdIndex, headsignIndex) {
                        let tripId = columns[tripIdIndex]
                        let headsign = columns[headsignIndex]
                        let parts = tripId.split(separator: "_")            // This is needed because trip_id contains different prefixes in real-time and static files
                        if parts.count == 5 {
                            let key = "\(parts[2])_\(parts[3])_\(parts[4])"
                            tripIdToDestination[key] = headsign
                        }
                    }
                }
            }
        }
        
        return tripIdToDestination
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {                      // Needed because splitting by comma could split wrongly if there are commas inside quoted fields
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        result.append(currentField)
        
        return result.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

