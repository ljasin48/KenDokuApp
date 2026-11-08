//
//  LandingView.swift
//  KenKen
//
//  Created by Logan Jasin on 11/7/26.
//

import SwiftUI

enum HomeRoute: Hashable {
    case newGame(GameLaunch)
    case howToPlay
    case dailyPuzzle
    case statistics
    case settings

    var title: String {
        switch self {
        case .newGame: "New Game"
        case .howToPlay: "How to Play"
        case .dailyPuzzle: "Daily Puzzle"
        case .statistics: "Statistics"
        case .settings: "Settings"
        }
    }
}

struct KenDokuBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                let step: CGFloat = 32
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(theme.gridLine), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }
}

private struct MenuOption: Identifiable {
    let route: HomeRoute
    let title: String
    let detail: String
    let symbol: String

    var id: HomeRoute { route }

    static let landing: [MenuOption] = [
        MenuOption(
            route: .howToPlay,
            title: "How to Play",
            detail: "Cages, operations, and the grid rule",
            symbol: "questionmark.circle"
        ),
        MenuOption(
            route: .dailyPuzzle,
            title: "Daily Puzzle",
            detail: "One shared board each day",
            symbol: "calendar"
        ),
        MenuOption(
            route: .statistics,
            title: "Statistics",
            detail: "Times, streaks, and solved grids",
            symbol: "chart.bar"
        )
    ]
}

struct LandingView: View {
    let startGame: (GameLaunch) -> Void

    @Environment(\.appTheme) private var theme
    @AppStorage(GameSettings.size) private var size = 4
    @AppStorage(GameSettings.difficulty) private var difficultyRaw = Difficulty.medium.rawValue
    @AppStorage(GameSettings.highlightMistakes) private var highlightMistakes = true
    @AppStorage(GameSettings.allowAdd) private var allowAdd = true
    @AppStorage(GameSettings.allowSubtract) private var allowSubtract = true
    @AppStorage(GameSettings.allowMultiply) private var allowMultiply = true
    @AppStorage(GameSettings.allowDivide) private var allowDivide = true
    @AppStorage(GameSettings.hideOperators) private var hideOperators = false

    private let rowSpacing: CGFloat = 12

    var body: some View {
        ViewThatFits(in: .vertical) {
            page(compact: false)
            page(compact: true)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { KenDokuBackground() }
        .navigationTitle("KenDoku")
        #if !os(macOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private func page(compact: Bool) -> some View {
        let spacing: CGFloat = compact ? 8 : rowSpacing
        let gap: CGFloat = compact ? 8 : 16
        return VStack(spacing: 0) {
            Spacer(minLength: gap)
            header(compact: compact)
            Spacer(minLength: gap)
            VStack(spacing: spacing) {
                menu(spacing: spacing, rowPadding: compact ? 8 : 14)
                startButton(rowPadding: compact ? 8 : 14)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, compact ? 8 : 12)
    }

    private func header(compact: Bool) -> some View {
        VStack(spacing: compact ? 2 : 6) {
            Text("KenDoku")
                .font(.system(size: compact ? 34 : 48, weight: .bold, design: .rounded))
            if !compact {
                Text("Arithmetic Sudoku")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func settingsCard(rowPadding: CGFloat) -> some View {
        NavigationLink(value: HomeRoute.settings) {
            HStack(spacing: 14) {
                Image(systemName: "gearshape")
                    .font(.body.weight(.semibold))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.headline)
                    Text(summaryLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, rowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .accessibilityHint("Opens game settings")
    }

    private func startButton(rowPadding: CGFloat) -> some View {
        Button {
            startGame(GameLaunch.random(size: resolvedSize, difficulty: difficulty))
        } label: {
            ZStack {
                VStack(spacing: 2) {
                    Text(" ").font(.headline)
                    Text(" ").font(.subheadline)
                }
                .hidden()
                .accessibilityHidden(true)

                Label("Start Game", systemImage: "play.fill")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, rowPadding)
        }
        .buttonStyle(.plain)
        .buttonSizing(.flexible)
        .glassEffect(.regular.tint(theme.accent).interactive(), in: .rect(cornerRadius: 22))
        .accessibilityHint("Starts a \(resolvedSize) by \(resolvedSize) \(difficulty.title) puzzle")
    }

    private var summaryLine: String {
        let symbols = rules.enabledOperations.map(\.symbol).joined(separator: " ")
        let noOp = rules.hidesOperators ? " · No-op" : ""
        return "\(resolvedSize)\u{00D7}\(resolvedSize) · \(difficulty.title) · \(symbols)\(noOp)"
    }

    private var rules: OperatorRules {
        OperatorRules(
            add: allowAdd,
            subtract: allowSubtract,
            multiply: allowMultiply,
            divide: allowDivide,
            hidesOperators: hideOperators
        ).normalized
    }

    private var difficulty: Difficulty {
        Difficulty(rawValue: difficultyRaw) ?? .medium
    }

    private var resolvedSize: Int {
        GameLaunch.sizes.contains(size) ? size : 4
    }

    private func menu(spacing: CGFloat, rowPadding: CGFloat) -> some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: spacing) {
                ForEach(MenuOption.landing) { option in
                    NavigationLink(value: option.route) {
                        HStack(spacing: 14) {
                            Image(systemName: option.symbol)
                                .font(.body.weight(.semibold))
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.headline)
                                Text(option.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, rowPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                }
                settingsCard(rowPadding: rowPadding)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LandingView { _ in }
            .kendokuScreen()
    }
    .kendokuScreen()
}
