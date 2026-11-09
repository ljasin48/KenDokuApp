//
//  ContentView.swift
//  KenKen
//
//  Created by Logan Jasin on 9/1/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
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
        .onChange(of: themeRaw, initial: true) {
            theme.applyIcon()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                theme.applyIcon()
            }
        }
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

/// Plain buttons otherwise hit-test only the opaque text, so the glass around it does nothing.
struct KenDokuHitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.interaction, Rectangle())
    }
}

struct KenDokuGlassButtonStyle: ButtonStyle {
    var glass: Glass
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.interaction, RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }
}

