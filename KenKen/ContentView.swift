//
//  ContentView.swift
//  KenKen
//
//  Created by Logan Jasin on 9/1/26.
//

import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    @AppStorage(GameSettings.theme) private var themeRaw = AppTheme.kendoku.rawValue

    private var theme: AppTheme {
        AppTheme(rawValue: themeRaw) ?? .kendoku
    }

    var body: some View {
        NavigationStack(path: $path) {
            LandingView { launch in
                path.append(HomeRoute.newGame(launch))
            }
            .kendokuScreen()
            .navigationDestination(for: HomeRoute.self) { route in
                HomeDestinationView(route: route)
                    .kendokuScreen()
            }
        }
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .environment(\.appTheme, theme)
        .kendokuScreen()
    }
}

#Preview {
    ContentView()
        .environment(PlayerStats.preview)
}
extension View {
    /// The inner display otherwise reserves a leading inset for a vertical dock.
    func kendokuScreen() -> some View {
        modifier(KenDokuScreenModifier())
    }
}

private struct KenDokuScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            content.toolbarVerticalBehavior(.disabled)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

