//
//  KenKenApp.swift
//  KenKen
//
//  Created by Logan Jasin on 9/1/26.
//

import SwiftUI

@main
struct KenKenApp: App {
    @State private var stats = PlayerStats()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(stats)
        }
    }
}
