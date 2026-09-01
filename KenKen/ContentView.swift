//
//  ContentView.swift
//  KenKen
//
//  Created by Logan Jasin on 9/1/26.
//

import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            LandingView {
                path.append(HomeRoute.newGame)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                HomeDestinationView(route: route)
            }
        }
        .tint(KenDokuColor.clay)
    }
}

#Preview {
    ContentView()
        .environment(PlayerStats.preview)
}
