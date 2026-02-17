//
//  MapView.swift
//  ZET-tracker Watch App
//
//  Created by Alen Jurina on 15.02.2026..
//

import SwiftUI
import MapKit
import Combine

struct MapView: View {
    @StateObject private var dataReceiver = WatchDataReceiver.shared
    @StateObject private var locationManager = LocationManager()
    
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.8150, longitude: 15.9819),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
        
    @State private var currentMapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(
            latitude: 45.8150,
            longitude: 15.9819
        )
    @State private var currentMapSpan: MKCoordinateSpan = MKCoordinateSpan(
        latitudeDelta: 0.05,
        longitudeDelta: 0.05
    )
    
    @State private var showTrams = true
    @State private var showBuses = true
    @State private var showFilterMenu = false
    
    private let visibleRadius: CLLocationDistance = 1000
        
    private var visibleVehicles: [VehicleData] {
        let mapCenterLocation = CLLocation(
            latitude: currentMapCenter.latitude,
            longitude: currentMapCenter.longitude
        )
        
        return dataReceiver.vehicles.filter { vehicle in
            
            let typeMatch = (vehicle.isTram && showTrams) || (!vehicle.isTram && showBuses)
            let vehicleLocation = CLLocation(
                latitude: vehicle.latitude,
                longitude: vehicle.longitude
            )
            let distance = mapCenterLocation.distance(from: vehicleLocation)
            let distanceMatch = distance <= visibleRadius
            return typeMatch && distanceMatch
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else {
            return "\(seconds / 3600)h"
        }
    }
    
    var body: some View {
        ZStack {
            Map(position: $position) {
                if let userLocation = locationManager.userLocation {
                    Annotation("", coordinate: userLocation) {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                
                ForEach(visibleVehicles) { vehicle in
                    Annotation(vehicle.destination ?? "", coordinate: CLLocationCoordinate2D(
                        latitude: vehicle.latitude,
                        longitude: vehicle.longitude
                    )) {
                        VehicleMarker(vehicle: vehicle)
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                currentMapCenter = context.region.center
                currentMapSpan = context.region.span
            }
            .overlay(alignment: .bottomTrailing) {
                VStack() {
                    if showFilterMenu {
                        VStack() {
                            Button {
                                showTrams.toggle()
                            } label: {
                                Image(systemName: "tram.fill")
                                    .font(.caption)
                                    .foregroundColor(showTrams ? .blue : .gray)
                            }
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .cornerRadius(18)
                            .glassEffect()
                            
                            Button {
                                showBuses.toggle()
                            } label: {
                                Image(systemName: "bus.fill")
                                    .font(.caption)
                                    .foregroundColor(showBuses ? .red : .gray)
                            }
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .cornerRadius(18)
                            .glassEffect()
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .topLeading)))
                    }
                    Button {
                        showFilterMenu.toggle()
                    } label: {
                        Image(systemName: showFilterMenu ? "xmark" : "line.3.horizontal.decrease.circle.fill")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18)
                    .glassEffect()
                    
                }
                .padding(.bottom, 20)
                .padding(.trailing, 20)
            }
            .overlay(alignment: .top) {
                if let lastUpdate = dataReceiver.lastUpdateTime {
                    TimelineView(.periodic(from: lastUpdate, by: 1.0)) { context in
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text(timeAgo(from: lastUpdate))
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green)
                        .clipShape(Capsule())
                        .padding(.top, 20)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                Button {
                    dataReceiver.requestVehiclesFromPhone()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .glassEffect()
                .padding(.bottom, 20)
            }
            .overlay(alignment: .bottomLeading) {
                Button(action: {
                    position = .userLocation(fallback: .automatic)
                }) {
                    Image(systemName: "location")
                        .foregroundColor(.blue)
                }
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .glassEffect()
                .padding(.bottom, 20)
                .padding(.leading, 20)
            }
            .ignoresSafeArea()
            .mapControls {
                MapCompass()
            }
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if let userLoc = locationManager.userLocation {
                    position = .region(
                        MKCoordinateRegion(
                            center: userLoc,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
        }
        .onDisappear {
            locationManager.stopUpdating()
        }
    }
}


struct VehicleMarker: View {
    let vehicle: VehicleData
    var body: some View {
        ZStack {
            Circle()
                .fill(vehicle.isTram ? .blue : .red)
                .frame(width: 24, height: 24)
            
            Text(vehicle.routeId)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
        }
        .glassEffect()
    }
}


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        if authorizationStatus == .authorizedWhenInUse ||
           authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
            
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied")
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
        }
    }
}

#Preview {
    let receiver = WatchDataReceiver.shared
    receiver.vehicles = VehicleData.mockZagrebCluster()
    receiver.lastUpdateTime = Date()
    
    return MapView()
}
