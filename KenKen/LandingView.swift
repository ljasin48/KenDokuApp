//
//  LandingView.swift
//  KenKen
//
//  Created by Logan Jasin on 11/7/26.
//

import SwiftUI

enum HomeRoute: Hashable {
    case newGame
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

enum KenDokuColor {
    static let clay = Color(red: 0.93, green: 0.45, blue: 0.27)
    static let ink = Color(red: 0.07, green: 0.11, blue: 0.15)
    static let moss = Color(red: 0.18, green: 0.34, blue: 0.32)
}

struct KenDokuBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [KenDokuColor.ink, KenDokuColor.moss, Color(red: 0.32, green: 0.16, blue: 0.12)],
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
                context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 1)
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
        ),
        MenuOption(
            route: .settings,
            title: "Settings",
            detail: "Size, difficulty, and mistake highlights",
            symbol: "gearshape"
        )
    ]
}

struct LandingView: View {
    let startGame: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                menu
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background { KenDokuBackground() }
        .navigationTitle("KenDoku")
        #if !os(macOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .preferredColorScheme(.dark)
        .safeAreaBar(edge: .bottom) {
            Button(action: startGame) {
                Label("Start Game", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .buttonSizing(.flexible)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .accessibilityHint("Opens a new puzzle")
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
//            Text("12+")
//                .font(.system(size: 40, weight: .bold, design: .rounded))
//                .frame(width: 104, height: 104)
//                .glassEffect(.regular, in: .rect(cornerRadius: 28))
//                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("KenDoku")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("Sudoku, solved with arithmetic.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 10) {
                    ForEach(["+", "\u{2212}", "\u{00D7}", "\u{00F7}"], id: \.self) { symbol in
                        Text(symbol)
                            .font(.headline)
                            .frame(width: 40, height: 40)
                            .glassEffect(.regular, in: .circle)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Addition, subtraction, multiplication, and division")
        }
    }

    private var menu: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 12) {
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
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LandingView {}
    }
}
