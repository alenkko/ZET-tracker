//
//  ContentView.swift
//  ZET-tracker
//
//  Created by Alen Jurina on 14.02.2026..
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {               // Creating two tabs
            VehicleListView()
                .tabItem {
                    Label("Vozila", systemImage: "list.bullet")
                }
            
            WatchControlView()
                .tabItem {
                    Label("Watch", systemImage: "applewatch")
                }
        }
    }
}

struct VehicleListView: View {                      // Tab for displaying fetched vehicles
    @State private var vehicles: [VehicleData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var showTrams = true
    @State private var showBuses = true
    
    private var filteredVehicles: [VehicleData] {           // Filter for trams and buses
        vehicles.filter { vehicle in
            if vehicle.isTram && showTrams { return true }
            if !vehicle.isTram && showBuses { return true }
            return false
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Učitavam vozila...")
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Greška")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Pokušaj ponovno") {
                            Task { await loadVehicles() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(filteredVehicles) { vehicle in
                        VehicleRow(vehicle: vehicle)
                    }
                }
            }
            .navigationTitle("ZET Vozila (\(vehicles.count))")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Button {
                            showTrams.toggle()
                        } label: {
                            Image(systemName: "tram.fill")
                                .foregroundColor(showTrams ? .blue : .gray)
                        }
                        
                        Button {
                            showBuses.toggle()
                        } label: {
                            Image(systemName: "bus.fill")
                                .foregroundColor(showBuses ? .red : .gray)
                        }
                    }
                    .padding(10)
                }
                
                ToolbarItem(placement: .topBarTrailing) {               // Refresh button
                    Button {
                        Task { await loadVehicles() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            await loadVehicles()
        }
    }
    
    private func loadVehicles() async {     // Fetch vehicles
        isLoading = true
        errorMessage = nil
        
        do {
            let fetcher = RealTimeFetcher()
            vehicles = try await fetcher.fetchVehicles()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

struct VehicleRow: View {           // Showing each vehicle data
    let vehicle: VehicleData
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: vehicle.isTram ? "tram.fill" : "bus.fill")
                .font(.title2)
                .foregroundColor(vehicle.isTram ? .blue : .red)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Linija \(vehicle.routeId)")
                    .font(.headline)
                
                Text("Vozilo: \(vehicle.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Ažurirano: \(vehicle.lastUpdateDate, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }
}

struct WatchControlView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var lastSentTime: Date?
    @State private var isSending = false
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                HStack {
                    Circle()
                        .fill(connectivityManager.isWatchReachable ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                    
                    Text(connectivityManager.isWatchReachable ? "Watch povezan" : "Watch nije povezan")
                        .foregroundColor(.secondary)
                }
                Image(systemName: "applewatch")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Button {                // Sending data to watch
                    Task {
                        isSending = true
                        await connectivityManager.sendVehiclesToWatch()
                        lastSentTime = Date()
                        isSending = false
                    }
                } label: {
                    HStack {
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Pošalji na Watch")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSending ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSending)
                .padding(.horizontal)
                
                if let lastSent = lastSentTime {            // If lastSentTime exists, show when data was last sent to watch
                    VStack(spacing: 4) {
                        Text("Zadnje poslano:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(lastSent, style: .relative)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Watch Kontrola")
        }
    }
}


#Preview {
    ContentView()
}
