//
//  LandingView.swift
//  KenDoku
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
        case .newGame(let launch): launch.isDaily ? "Daily Puzzle" : "New Game"
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
    @Environment(ActiveGame.self) private var activeGame
    @Environment(PlayerStats.self) private var stats
    @State private var confirmReplace = false
    @State private var pendingLaunch: GameLaunch?
    @AppStorage(GameSettings.size) private var size = 4
    @AppStorage(GameSettings.difficulty) private var difficultyRaw = Difficulty.medium.rawValue
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
        .confirmationDialog("Replace your current game?", isPresented: $confirmReplace, titleVisibility: .visible) {
            Button("Replace", role: .destructive) {
                if let pendingLaunch {
                    startGame(pendingLaunch)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The puzzle you were playing will be discarded.")
        }
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
                gameActions(rowPadding: compact ? 8 : 14)
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
        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 22))
        .accessibilityHint("Opens game settings")
    }

    @ViewBuilder
    private func gameActions(rowPadding: CGFloat) -> some View {
        if let game = activeGame.game {
            HStack(spacing: 12) {
                resumeButton(game, rowPadding: rowPadding)
                newGameButton(rowPadding: rowPadding)
            }
        } else {
            startButton(rowPadding: rowPadding)
        }
    }

    private func resumeButton(_ game: SavedGame, rowPadding: CGFloat) -> some View {
        Button {
            startGame(game.launch)
        } label: {
            VStack(spacing: 2) {
                Text("Resume")
                    .font(.headline)
                Text(game.summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, rowPadding)
        }
        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.tint(theme.accent).interactive(), cornerRadius: 22))
        .buttonSizing(.flexible)
        .accessibilityHint("Continues the saved puzzle")
    }

    private func newGameButton(rowPadding: CGFloat) -> some View {
        Button {
            begin(GameLaunch.random(size: resolvedSize, difficulty: difficulty))
        } label: {
            actionLabel("New Game", systemImage: "plus")
                .padding(.horizontal, 16)
                .padding(.vertical, rowPadding)
        }
        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 22))
        .buttonSizing(.flexible)
        .accessibilityHint("Starts a puzzle and discards the saved one")
    }

    private func startButton(rowPadding: CGFloat) -> some View {
        Button {
            begin(GameLaunch.random(size: resolvedSize, difficulty: difficulty))
        } label: {
            actionLabel("Start Game", systemImage: "play.fill")
                .padding(.horizontal, 16)
                .padding(.vertical, rowPadding)
        }
        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.tint(theme.accent).interactive(), cornerRadius: 22))
        .buttonSizing(.flexible)
        .accessibilityHint("Starts a \(resolvedSize) by \(resolvedSize) \(difficulty.title) puzzle")
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        ZStack {
            VStack(spacing: 2) {
                Text(" ").font(.headline)
                Text(" ").font(.subheadline)
            }
            .hidden()
            .accessibilityHidden(true)

            Label(title, systemImage: systemImage)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
    }

    private func begin(_ launch: GameLaunch) {
        if launch.isDaily, stats.completedDailyToday { return }
        if let game = activeGame.game, !game.matches(launch) {
            pendingLaunch = launch
            confirmReplace = true
        } else {
            startGame(launch)
        }
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
                    if option.route == .dailyPuzzle {
                        Button {
                            begin(GameLaunch.daily())
                        } label: {
                            menuLabel(
                                option,
                                detail: dailyDetail,
                                rowPadding: rowPadding,
                                trailing: stats.completedDailyToday ? "checkmark" : "chevron.forward"
                            )
                        }
                        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 22))
                        .disabled(stats.completedDailyToday)
                        .accessibilityHint(
                            stats.completedDailyToday
                                ? "Today's puzzle is already completed"
                                : "Opens today's puzzle"
                        )
                    } else {
                        NavigationLink(value: option.route) {
                            menuLabel(option, detail: option.detail, rowPadding: rowPadding)
                        }
                        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 22))
                    }
                }
                settingsCard(rowPadding: rowPadding)
            }
        }
    }

    private func menuLabel(
        _ option: MenuOption,
        detail: String,
        rowPadding: CGFloat,
        trailing: String = "chevron.forward"
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: option.symbol)
                .font(.body.weight(.semibold))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: trailing)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dailyDetail: String {
        if stats.completedDailyToday {
            return "Completed today"
        }
        if activeGame.game?.isTodayDaily == true {
            return "Continue today's board"
        }
        return "One shared board each day"
    }
}

#Preview {
    NavigationStack {
        LandingView { _ in }
            .kendokuScreen()
    }
    .kendokuScreen()
    .environment(ActiveGame.preview)
    .environment(PlayerStats.preview)
}
