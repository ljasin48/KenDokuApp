//
//  ContentView.swift
//  Mathdoku
//
//  Created by Logan Jasin on 9/1/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(GameDeck.self) private var gameDeck
    @State private var path = NavigationPath()
    @AppStorage(GameSettings.theme) private var themeRaw = AppTheme.mathdoku.rawValue
    @AppStorage(GameSettings.size) private var size = 4
    @AppStorage(GameSettings.difficulty) private var difficultyRaw = Difficulty.medium.rawValue
    @AppStorage(GameSettings.allowAdd) private var allowAdd = true
    @AppStorage(GameSettings.allowSubtract) private var allowSubtract = true
    @AppStorage(GameSettings.allowMultiply) private var allowMultiply = true
    @AppStorage(GameSettings.allowDivide) private var allowDivide = true

    private var theme: AppTheme {
        AppTheme(rawValue: themeRaw) ?? .mathdoku
    }

    private var boardSpec: GameDeck.Spec {
        let resolved = GameLaunch.sizes.contains(size) ? size : 4
        let difficulty = Difficulty(rawValue: difficultyRaw) ?? .medium
        let rules = OperatorRules(
            add: allowAdd,
            subtract: allowSubtract,
            multiply: allowMultiply,
            divide: allowDivide,
            hidesOperators: false
        )
        return GameDeck.Spec(size: resolved, difficulty: difficulty, rules: rules)
    }

    var body: some View {
        NavigationStack(path: $path) {
            LandingView(
                startGame: { launch in
                    path.append(HomeRoute.newGame(launch))
                },
                startTutorial: {
                    path.append(HomeRoute.tutorial)
                }
            )
            .mathdokuScreen()
            .navigationDestination(for: HomeRoute.self) { route in
                HomeDestinationView(route: route)
                    .mathdokuScreen()
            }
        }
        .tint(theme.accent)
        .preferredColorScheme(.dark)
        .environment(\.appTheme, theme)
        .mathdokuScreen()
        .onChange(of: themeRaw, initial: true) {
            theme.applyIcon()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                theme.applyIcon()
            }
        }
        .onChange(of: boardSpec) {
            gameDeck.prepare(boardSpec, debounced: true)
        }
    }
}

#Preview {
    ContentView()
        .environment(PlayerStats.preview)
        .environment(ActiveGame.preview)
        .environment(GameDeck.preview)
}
extension View {
    /// The inner display otherwise reserves a leading inset for a vertical dock.
    func mathdokuScreen() -> some View {
        modifier(MathdokuScreenModifier())
    }
}

private struct MathdokuScreenModifier: ViewModifier {
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
struct MathdokuHitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.interaction, Rectangle())
    }
}

struct MathdokuGlassButtonStyle: ButtonStyle {
    var glass: Glass
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.interaction, RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }
}

