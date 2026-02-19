//
//  ZET_trackerApp.swift
//  ZET-tracker
//
//  Created by Alen Jurina on 14.02.2026..
//

import SwiftUI

@main
struct ZET_trackerApp: App {
    init() {                                  // Initialize the WatchConnectivityManager to start listening for messages from the watch
        _ = WatchConnectivityManager.shared
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
