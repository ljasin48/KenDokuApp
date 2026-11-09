//
//  GameExtrasView.swift
//  KenKen
//
//  Created by Logan Jasin on 11/7/26.
//

import SwiftUI

struct StatisticsView: View {
    @Environment(PlayerStats.self) private var stats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statRow("Solved", value: "\(stats.record.solved)")
                statRow("Daily solved", value: "\(stats.record.dailySolved)")
                statRow("Current streak", value: "\(stats.record.currentStreak)")
                statRow("Best streak", value: "\(stats.record.bestStreak)")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Best times")
                        .font(.headline)
                    if bestTimes.isEmpty {
                        Text("Finish a puzzle without hints to record a time.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(bestTimes) { entry in
                            HStack {
                                Text(entry.title)
                                Spacer()
                                Text(clock(entry.seconds))
                                    .monospacedDigit()
                            }
                            .font(.body)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))

                Text("The streak counts daily puzzles solved on consecutive days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func statRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var bestTimes: [BestTime] {
        stats.record.bestSeconds.compactMap { key, seconds in
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let size = Int(parts[0]),
                  let difficulty = Difficulty(rawValue: String(parts[1]))
            else { return nil }
            return BestTime(id: key, size: size, difficulty: difficulty, seconds: seconds)
        }
        .sorted { lhs, rhs in
            if lhs.size != rhs.size { return lhs.size < rhs.size }
            let order = Difficulty.allCases
            return (order.firstIndex(of: lhs.difficulty) ?? 0) < (order.firstIndex(of: rhs.difficulty) ?? 0)
        }
    }

    private func clock(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}

private struct BestTime: Identifiable {
    let id: String
    let size: Int
    let difficulty: Difficulty
    let seconds: Int

    var title: String { "\(size)\u{00D7}\(size) \(difficulty.title)" }
}

struct SettingsView: View {
    @AppStorage(GameSettings.size) private var size = 4
    @AppStorage(GameSettings.difficulty) private var difficultyRaw = Difficulty.medium.rawValue
    @AppStorage(GameSettings.highlightMistakes) private var highlightMistakes = true
    @AppStorage(GameSettings.theme) private var themeRaw = AppTheme.kendoku.rawValue

    private var difficulty: Difficulty {
        Difficulty(rawValue: difficultyRaw) ?? .medium
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                gameplaySettings
                appSettings
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear {
            if !GameLaunch.sizes.contains(size) {
                size = 4
            }
            if AppTheme(rawValue: themeRaw) == nil {
                themeRaw = AppTheme.kendoku.rawValue
            }
        }
    }

    private var gameplaySettings: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionHeader("Gameplay", detail: "Start Game uses these choices.")

            VStack(alignment: .leading, spacing: 10) {
                Text("Size")
                    .font(.headline)
                Picker("Size", selection: $size) {
                    ForEach(GameLaunch.sizes, id: \.self) { value in
                        Text("\(value)\u{00D7}\(value)").tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Difficulty")
                    .font(.headline)
                Picker("Difficulty", selection: $difficultyRaw) {
                    ForEach(Difficulty.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            OperatorRulesEditor()

            Toggle(isOn: $highlightMistakes) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Highlight mistakes")
                    Text("Mark repeated numbers and finished cages that miss their target.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }

    private var appSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("App", detail: "Theme changes the app and its icon.")

            ForEach(AppTheme.allCases) { theme in
                themeButton(theme)
            }
        }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private func themeButton(_ theme: AppTheme) -> some View {
        let isSelected = themeRaw == theme.rawValue
        return Button {
            themeRaw = theme.rawValue
        } label: {
            HStack(spacing: 14) {
                Image(theme.iconAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.title)
                        .font(.headline)
                    Text(theme.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(
            KenDokuGlassButtonStyle(
                glass: isSelected ? .regular.tint(theme.accent).interactive() : .regular.interactive(),
                cornerRadius: 20
            )
        )
        .accessibilityLabel(theme.title)
        .accessibilityValue(theme.detail)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
            .kendokuScreen()
    }
    .kendokuScreen()
    .environment(PlayerStats.preview)
}
