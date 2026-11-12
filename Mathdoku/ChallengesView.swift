//
//  ChallengesView.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/12/26.
//

import SwiftUI

struct ChallengesView: View {
    @Environment(PlayerStats.self) private var stats
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(ChallengeCatalog.groups(for: stats.record)) { group in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(group.title)
                            .font(.headline)
                        ForEach(group.items) { item in
                            challengeRow(item)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func challengeRow(_ item: ChallengeItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.title)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                accoladeMark(item)
            }
            ProgressView(value: item.fraction)
                .tint(theme.accent)
            Text(item.status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.accessibilityValue)
    }

    @ViewBuilder
    private func accoladeMark(_ item: ChallengeItem) -> some View {
        if item.usesAccolades {
            Image(systemName: item.accolade == nil ? "medal" : "medal.fill")
                .font(.title3)
                .foregroundStyle(item.accolade?.color ?? Color.secondary)
                .accessibilityHidden(true)
        } else if item.isDone {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
        }
    }
}

private struct ChallengeGroup: Identifiable {
    var title: String
    var items: [ChallengeItem]

    var id: String { title }
}

private struct ChallengeItem: Identifiable {
    var title: String
    var fraction: Double
    var status: String
    var isDone: Bool
    var usesAccolades = false
    var accolade: Accolade?

    var id: String { title }

    var accessibilityValue: String {
        if let accolade {
            return "\(accolade.title). \(status)"
        }
        if isDone {
            return "Complete. \(status)"
        }
        return status
    }
}

private enum Accolade: Int, CaseIterable {
    case bronze
    case silver
    case gold
    case platinum

    var title: String {
        switch self {
        case .bronze: "Bronze"
        case .silver: "Silver"
        case .gold: "Gold"
        case .platinum: "Platinum"
        }
    }

    var color: Color {
        switch self {
        case .bronze: Color(red: 0.80, green: 0.50, blue: 0.28)
        case .silver: Color(red: 0.78, green: 0.82, blue: 0.86)
        case .gold: Color(red: 0.93, green: 0.76, blue: 0.32)
        case .platinum: Color(red: 0.62, green: 0.84, blue: 0.96)
        }
    }

    static let gameThresholds = [10, 100, 500, 1000]
    static let streakThresholds = [7, 30, 90, 365]
}

private enum ChallengeCatalog {
    /// Slowest to fastest. Platinum keeps the original time goal for 4×4, 6×6, and 9×9.
    private static let speedLimits: [Int: [Int]] = [
        3: [5 * 60, 3 * 60, 2 * 60, 60],
        4: [8 * 60, 4 * 60, 3 * 60, 2 * 60],
        5: [12 * 60, 8 * 60, 5 * 60, 3 * 60],
        6: [15 * 60, 10 * 60, 7 * 60, 5 * 60],
        7: [20 * 60, 15 * 60, 10 * 60, 7 * 60],
        8: [25 * 60, 18 * 60, 12 * 60, 8 * 60],
        9: [30 * 60, 20 * 60, 15 * 60, 10 * 60]
    ]

    static func groups(for record: PlayerRecord) -> [ChallengeGroup] {
        let games = [
            tiers("Play games", record.played, thresholds: Accolade.gameThresholds),
            tiers("Complete games", record.completed, thresholds: Accolade.gameThresholds),
            tiers("Perfect games", record.perfect, thresholds: Accolade.gameThresholds)
        ]
        let daily = [
            tiers("Solve daily puzzles", record.dailySolved, thresholds: Accolade.streakThresholds),
            tiers("Daily streak", record.bestStreak, thresholds: Accolade.streakThresholds)
        ]
        let boards = [
            count("Complete a 9\u{00D7}9", record.bySize[9]?.completed ?? 0, of: 1),
            count(
                "Perfect a hard 9\u{00D7}9",
                record.perfectByKey["9-\(Difficulty.hard.rawValue)"] ?? 0,
                of: 1
            ),
            sizes("Complete every size board") { (record.bySize[$0]?.completed ?? 0) > 0 },
            sizes("Perfect every size board") { (record.bySize[$0]?.perfect ?? 0) > 0 },
            sizes("Complete every size board on hard") {
                (record.completedByKey["\($0)-\(Difficulty.hard.rawValue)"] ?? 0) > 0
            },
            sizes("Perfect every size board on hard") {
                (record.perfectByKey["\($0)-\(Difficulty.hard.rawValue)"] ?? 0) > 0
            }
        ]
        let speed = GameLaunch.sizes.map { speed(size: $0, record: record) }
        let sections = [games, daily, boards, speed]
        return [
            ChallengeGroup(title: "Overall", items: [
                collection("Complete all game challenges", games),
                collection("Complete all daily challenges", daily),
                collection("Complete all board challenges", boards),
                collection("Complete all speed challenges", speed),
                collection("Complete all challenges", sections.flatMap { $0 })
            ]),
            ChallengeGroup(title: "Games", items: games),
            ChallengeGroup(title: "Daily", items: daily),
            ChallengeGroup(title: "Boards", items: boards),
            ChallengeGroup(title: "Speed", items: speed)
        ]
    }

    private static func collection(_ title: String, _ items: [ChallengeItem]) -> ChallengeItem {
        let done = items.filter(\.isDone).count
        let goal = max(items.count, 1)
        return ChallengeItem(
            title: title,
            fraction: Double(done) / Double(goal),
            status: "\(done) of \(goal)",
            isDone: done == items.count && !items.isEmpty
        )
    }

    private static func tiers(_ title: String, _ current: Int, thresholds: [Int]) -> ChallengeItem {
        let nextIndex = thresholds.firstIndex { current < $0 }
        let earnedIndex = (nextIndex ?? thresholds.count) - 1
        let accolade = earnedIndex >= 0 ? Accolade.allCases[earnedIndex] : nil
        let goal = thresholds[nextIndex ?? thresholds.count - 1]
        let done = nextIndex == nil
        return ChallengeItem(
            title: title,
            fraction: done ? 1 : min(1, Double(max(current, 0)) / Double(goal)),
            status: "\(min(max(current, 0), goal)) of \(goal)",
            isDone: done,
            usesAccolades: true,
            accolade: accolade
        )
    }

    private static func sizes(_ title: String, done: (Int) -> Bool) -> ChallengeItem {
        count(title, GameLaunch.sizes.filter(done).count, of: GameLaunch.sizes.count)
    }

    private static func count(_ title: String, _ current: Int, of goal: Int) -> ChallengeItem {
        let safeGoal = max(goal, 1)
        let done = current >= safeGoal
        return ChallengeItem(
            title: title,
            fraction: min(1, Double(current) / Double(safeGoal)),
            status: "\(min(current, safeGoal)) of \(safeGoal)",
            isDone: done
        )
    }

    private static func speed(size: Int, record: PlayerRecord) -> ChallengeItem {
        let limits = speedLimits[size] ?? []
        let platinum = limits.last ?? 0
        let title = "Complete a \(size)\u{00D7}\(size) in under \(clock(platinum))"
        guard let best = record.fastestFinish[size] else {
            return ChallengeItem(
                title: title,
                fraction: 0,
                status: "incomplete",
                isDone: false,
                usesAccolades: true
            )
        }

        let earnedIndex = limits.lastIndex { best <= $0 }
        let accolade = earnedIndex.map { Accolade.allCases[$0] }
        let done = earnedIndex == limits.count - 1 && !limits.isEmpty
        let fraction: Double
        if done {
            fraction = 1
        } else if let earnedIndex, earnedIndex + 1 < limits.count {
            let currentLimit = limits[earnedIndex]
            let nextLimit = limits[earnedIndex + 1]
            let span = Double(currentLimit - nextLimit)
            let traveled = Double(currentLimit - best)
            fraction = span > 0 ? min(1, max(0, traveled / span)) : 0
        } else if let bronze = limits.first {
            fraction = min(1, Double(bronze) / Double(max(best, 1)))
        } else {
            fraction = 0
        }
        return ChallengeItem(
            title: title,
            fraction: fraction,
            status: clock(best),
            isDone: done,
            usesAccolades: true,
            accolade: accolade
        )
    }

    private static func clock(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}

#Preview {
    NavigationStack {
        ChallengesView()
            .mathdokuScreen()
    }
    .mathdokuScreen()
    .environment(PlayerStats.preview)
}
