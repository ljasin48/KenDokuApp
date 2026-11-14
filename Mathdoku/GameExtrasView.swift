//
//  GameExtrasView.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/7/26.
//

import SwiftUI

struct StatisticsView: View {
    @Environment(PlayerStats.self) private var stats
    @State private var selectedSize = 4
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statGroup(
                    "Overall",
                    rows: [
                        ("Played", "\(stats.record.played)"),
                        ("Solved", countPercent(stats.record.completed, of: stats.record.played)),
                        ("Perfected", countPercent(stats.record.perfect, of: stats.record.played)),
                        ("Time played", duration(stats.record.playSeconds))
                    ]
                )

                statGroup(
                    "Daily",
                    rows: [
                        ("Solved", "\(stats.record.dailySolved)"),
                        ("Current streak", "\(stats.record.currentStreak)"),
                        ("Best streak", "\(stats.record.bestStreak)"),
                        ("Best time", clock(stats.record.bestDailySeconds ?? 0))
                    ]
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Size")
                        .font(.headline)
                    Picker(selection: $selectedSize) {
                        ForEach(GameLaunch.sizes, id: \.self) { value in
                            Text("\(value)\u{00D7}\(value)").tag(value)
                        }
                    } label: {
                        Text("Size")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                sizeGroup(selectedSize)

                Text("A perfect game is solved with no hints or wrong numbers. The streak counts daily puzzles solved on consecutive days. Best times only count if no hints are used. Time played is the time spent on puzzles.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Text("Reset Statistics")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(MathdokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 20))
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear {
            if !GameLaunch.sizes.contains(selectedSize) {
                selectedSize = 4
            }
        }
        .confirmationDialog("Reset all statistics and challenges?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset Statistics and Challenges", role: .destructive) {
                stats.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All statistics and challenges will be reset. This cannot be undone. Today's daily puzzle can be played again.")
        }
    }

    private func sizeGroup(_ size: Int) -> some View {
        let totals = stats.record.bySize[size] ?? SizeStats()
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(size)\u{00D7}\(size)")
                .font(.headline)
            statLine("Played", "\(totals.played)")
            statLine("Solved", countPercent(totals.completed, of: totals.played))
            statLine("Perfected", countPercent(totals.perfect, of: totals.played))
            Text("Best times")
                .font(.headline)
                .padding(.top, 6)
            ForEach(Difficulty.allCases) { difficulty in
                statLine(difficulty.title, clock(bestSeconds(size: size, difficulty: difficulty)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func statGroup(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                statLine(row.0, row.1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func statLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold).monospacedDigit())
        }
    }

    private func countPercent(_ count: Int, of total: Int) -> String {
        guard total > 0 else { return "\(count) (0%)" }
        let percent = Int((Double(count) / Double(total) * 100).rounded())
        return "\(count) (\(percent)%)"
    }

    private func bestSeconds(size: Int, difficulty: Difficulty) -> Int {
        stats.record.bestSeconds["\(size)-\(difficulty.rawValue)"] ?? 0
    }

    private func clock(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    private func duration(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct MistakeHighlightPicker: View {
    @Environment(\.appTheme) private var theme
    @AppStorage(GameSettings.mistakeHighlight) private var highlightRaw = ""

    private var mistakeHighlight: MistakeHighlight {
        GameSettings.resolvedMistakeHighlight(stored: highlightRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Highlight mistakes")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(MistakeHighlight.allCases) { mode in
                    if mode != MistakeHighlight.allCases.first {
                        Divider()
                    }
                    option(mode)
                }
            }
            .padding(.horizontal, 16)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }

    private func option(_ mode: MistakeHighlight) -> some View {
        let isSelected = mistakeHighlight == mode
        return Button {
            highlightRaw = mode.rawValue
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.body.weight(.semibold))
                    Text(mode.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? theme.accent : .secondary)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(MathdokuHitButtonStyle())
        .accessibilityLabel(mode.title)
        .accessibilityValue(mode.detail)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct LeftHandModeToggle: View {
    @AppStorage(GameSettings.leftHand) private var leftHand = false

    var body: some View {
        Toggle(isOn: $leftHand) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Left-hand mode")
                Text("Moves the buttons to the left in landscape.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

/// Settings that can change during a puzzle without replacing the board.
struct PlaySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MistakeHighlightPicker()
                    LeftHandModeToggle()
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background { MathdokuBackground() }
            .navigationTitle("Settings")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .mathdokuScreen()
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }
}

struct SettingsView: View {
    @Environment(\.appTheme) private var theme
    @AppStorage(GameSettings.size) private var size = 4
    @AppStorage(GameSettings.difficulty) private var difficultyRaw = Difficulty.medium.rawValue
    @AppStorage(GameSettings.theme) private var themeRaw = AppTheme.mathdoku.rawValue

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
                themeRaw = AppTheme.mathdoku.rawValue
            }
        }
    }

    private var gameplaySettings: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionHeader("Gameplay Settings", detail: "")

            VStack(alignment: .leading, spacing: 10) {
                Text("Size")
                    .font(.headline)
                segmentedPicker("Size", selection: $size) {
                    ForEach(GameLaunch.sizes, id: \.self) { value in
                        Text("\(value)\u{00D7}\(value)").tag(value)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Difficulty")
                    .font(.headline)
                segmentedPicker("Difficulty", selection: $difficultyRaw) {
                    ForEach(Difficulty.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
            }

            OperatorRulesEditor()

            MistakeHighlightPicker()
        }
    }

    private var appSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Application Settings", detail: "")

            LeftHandModeToggle()

            Text("Theme")
                .font(.headline)
            ForEach(AppTheme.allCases) { theme in
                themeButton(theme)
            }
        }
    }

    /// The title stays on the picker for accessibility. Hiding it, rather than
    /// passing an empty title, removes the label column so the segments line up
    /// with the header.
    private func segmentedPicker<Selection: Hashable, Content: View>(
        _ title: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Picker(selection: selection) {
            content()
        } label: {
            Text(title)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
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
            MathdokuGlassButtonStyle(
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
            .mathdokuScreen()
    }
    .mathdokuScreen()
    .environment(PlayerStats.preview)
}
