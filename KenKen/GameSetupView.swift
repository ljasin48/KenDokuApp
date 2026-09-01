//
//  GameSetupView.swift
//  KenKen
//
//  Created by Logan Jasin on 11/7/26.
//

import SwiftUI

enum GameSettings {
    static let size = "kendoku.size"
    static let difficulty = "kendoku.difficulty"
    static let highlightMistakes = "kendoku.highlightMistakes"
}

struct GameLaunch: Hashable {
    var size: Int
    var difficulty: Difficulty
    var seed: UInt64?
    var isDaily: Bool
    var id: UInt64

    static let sizes = [3, 4, 5, 6]

    static func daily(on date: Date = .now) -> GameLaunch {
        let seed = DayStamp.seed(from: date)
        return GameLaunch(size: 5, difficulty: .medium, seed: seed, isDaily: true, id: seed)
    }

    static func random(size: Int, difficulty: Difficulty) -> GameLaunch {
        GameLaunch(
            size: size,
            difficulty: difficulty,
            seed: nil,
            isDaily: false,
            id: UInt64.random(in: 1...UInt64.max)
        )
    }
}

struct GameSetupView: View {
    @AppStorage(GameSettings.size) private var size = 4
    @AppStorage(GameSettings.difficulty) private var difficultyRaw = Difficulty.medium.rawValue
    @State private var launch: GameLaunch?

    private var difficulty: Difficulty {
        Difficulty(rawValue: difficultyRaw) ?? .medium
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Pick a size and difficulty. Each row and column uses every number once, and every cage has to hit its target.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Size")
                        .font(.headline)
                    Picker("Size", selection: $size) {
                        ForEach(GameLaunch.sizes, id: \.self) { value in
                            Text("\(value)\u{00D7}\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Board size")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Difficulty")
                        .font(.headline)
                    ForEach(Difficulty.allCases) { item in
                        Button {
                            difficultyRaw = item.rawValue
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 8)
                                if difficulty == item {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(KenDokuColor.clay)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                        .accessibilityAddTraits(difficulty == item ? .isSelected : [])
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaBar(edge: .bottom) {
            Button {
                launch = GameLaunch.random(size: resolvedSize, difficulty: difficulty)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .buttonSizing(.flexible)
            .controlSize(.large)
            .padding(.horizontal, 20)
        }
        .navigationDestination(item: $launch) { launch in
            GamePlayView(launch: launch)
        }
        .onAppear {
            if !GameLaunch.sizes.contains(size) {
                size = 4
            }
        }
    }

    private var resolvedSize: Int {
        GameLaunch.sizes.contains(size) ? size : 4
    }
}

#Preview {
    NavigationStack {
        GameSetupView()
    }
}
