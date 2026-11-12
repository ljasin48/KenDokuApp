//
//  PlayerStats.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/7/26.
//

import Foundation
import Observation

struct SizeStats: Codable, Equatable {
    var played = 0
    var completed = 0
    var perfect = 0
}

struct PlayerRecord: Codable, Equatable {
    var solved = 0
    var dailySolved = 0
    var currentStreak = 0
    var bestStreak = 0
    var lastDailyDay: String?
    var bestDailySeconds: Int?
    var bestSeconds: [String: Int] = [:]
    var played = 0
    var completed = 0
    var perfect = 0
    var bySize: [Int: SizeStats] = [:]
    /// Fastest finish for each board size, in seconds, including finishes that used a hint.
    var fastestFinish: [Int: Int] = [:]
    /// Perfect finishes keyed by "\(size)-\(difficulty.rawValue)".
    var perfectByKey: [String: Int] = [:]
    /// Finishes keyed by "\(size)-\(difficulty.rawValue)", including imperfect ones.
    var completedByKey: [String: Int] = [:]
    /// No-op is a subset of the counts above. A hidden-operation game still counts as a normal game.
    var noOpPlayed = 0
    var noOpCompleted = 0
    var noOpPerfect = 0
    var noOpBySize: [Int: SizeStats] = [:]
    var noOpPerfectByKey: [String: Int] = [:]
    var noOpCompletedByKey: [String: Int] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        solved = try container.decodeIfPresent(Int.self, forKey: .solved) ?? 0
        dailySolved = try container.decodeIfPresent(Int.self, forKey: .dailySolved) ?? 0
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        bestStreak = try container.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        lastDailyDay = try container.decodeIfPresent(String.self, forKey: .lastDailyDay)
        bestDailySeconds = try container.decodeIfPresent(Int.self, forKey: .bestDailySeconds)
        bestSeconds = try container.decodeIfPresent([String: Int].self, forKey: .bestSeconds) ?? [:]
        played = try container.decodeIfPresent(Int.self, forKey: .played) ?? 0
        completed = try container.decodeIfPresent(Int.self, forKey: .completed) ?? 0
        perfect = try container.decodeIfPresent(Int.self, forKey: .perfect) ?? 0
        bySize = try container.decodeIfPresent([Int: SizeStats].self, forKey: .bySize) ?? [:]
        if container.contains(.fastestFinish) {
            fastestFinish = try container.decodeIfPresent([Int: Int].self, forKey: .fastestFinish) ?? [:]
        } else {
            fastestFinish = Self.derivedFastestFinish(from: bestSeconds)
        }
        perfectByKey = try container.decodeIfPresent([String: Int].self, forKey: .perfectByKey) ?? [:]
        completedByKey = try container.decodeIfPresent([String: Int].self, forKey: .completedByKey) ?? [:]
        noOpPlayed = try container.decodeIfPresent(Int.self, forKey: .noOpPlayed) ?? 0
        noOpCompleted = try container.decodeIfPresent(Int.self, forKey: .noOpCompleted) ?? 0
        noOpPerfect = try container.decodeIfPresent(Int.self, forKey: .noOpPerfect) ?? 0
        noOpBySize = try container.decodeIfPresent([Int: SizeStats].self, forKey: .noOpBySize) ?? [:]
        noOpPerfectByKey = try container.decodeIfPresent([String: Int].self, forKey: .noOpPerfectByKey) ?? [:]
        noOpCompletedByKey = try container.decodeIfPresent([String: Int].self, forKey: .noOpCompletedByKey) ?? [:]
    }

    /// Older stats files stored hint-free best times only. Use the fastest of those per size until a new finish is recorded.
    private static func derivedFastestFinish(from bestSeconds: [String: Int]) -> [Int: Int] {
        var fastest: [Int: Int] = [:]
        for (key, seconds) in bestSeconds {
            guard let size = Int(key.split(separator: "-").first ?? "") else { continue }
            if let existing = fastest[size] {
                fastest[size] = min(existing, seconds)
            } else {
                fastest[size] = seconds
            }
        }
        return fastest
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(solved, forKey: .solved)
        try container.encode(dailySolved, forKey: .dailySolved)
        try container.encode(currentStreak, forKey: .currentStreak)
        try container.encode(bestStreak, forKey: .bestStreak)
        try container.encodeIfPresent(lastDailyDay, forKey: .lastDailyDay)
        try container.encodeIfPresent(bestDailySeconds, forKey: .bestDailySeconds)
        try container.encode(bestSeconds, forKey: .bestSeconds)
        try container.encode(played, forKey: .played)
        try container.encode(completed, forKey: .completed)
        try container.encode(perfect, forKey: .perfect)
        try container.encode(bySize, forKey: .bySize)
        try container.encode(fastestFinish, forKey: .fastestFinish)
        try container.encode(perfectByKey, forKey: .perfectByKey)
        try container.encode(completedByKey, forKey: .completedByKey)
        try container.encode(noOpPlayed, forKey: .noOpPlayed)
        try container.encode(noOpCompleted, forKey: .noOpCompleted)
        try container.encode(noOpPerfect, forKey: .noOpPerfect)
        try container.encode(noOpBySize, forKey: .noOpBySize)
        try container.encode(noOpPerfectByKey, forKey: .noOpPerfectByKey)
        try container.encode(noOpCompletedByKey, forKey: .noOpCompletedByKey)
    }

    private enum CodingKeys: String, CodingKey {
        case solved, dailySolved, currentStreak, bestStreak, lastDailyDay, bestDailySeconds, bestSeconds
        case played, completed, perfect, bySize, fastestFinish, perfectByKey, completedByKey
        case noOpPlayed, noOpCompleted, noOpPerfect, noOpBySize, noOpPerfectByKey, noOpCompletedByKey
    }
}

@Observable
final class PlayerStats {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey = "mathdoku.stats"

    private(set) var record: PlayerRecord

    var completedDailyToday: Bool {
        record.lastDailyDay == DayStamp.string()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(PlayerRecord.self, from: data) {
            record = decoded
        } else {
            record = PlayerRecord()
        }
    }

    func recordStart(size: Int, hidesOperators: Bool) {
        var next = record
        next.played += 1
        next.bySize[size, default: SizeStats()].played += 1
        if hidesOperators {
            next.noOpPlayed += 1
            next.noOpBySize[size, default: SizeStats()].played += 1
        }
        store(next)
    }

    func recordWin(seconds: Int, launch: GameLaunch, countsForBestTime: Bool, perfect: Bool, hidesOperators: Bool) {
        var next = record
        next.solved += 1
        next.completed += 1
        next.bySize[launch.size, default: SizeStats()].completed += 1
        let launchKey = "\(launch.size)-\(launch.difficulty.rawValue)"
        next.completedByKey[launchKey, default: 0] += 1
        if perfect {
            next.perfect += 1
            next.bySize[launch.size, default: SizeStats()].perfect += 1
            next.perfectByKey[launchKey, default: 0] += 1
        }
        if hidesOperators {
            next.noOpCompleted += 1
            next.noOpBySize[launch.size, default: SizeStats()].completed += 1
            next.noOpCompletedByKey[launchKey, default: 0] += 1
            if perfect {
                next.noOpPerfect += 1
                next.noOpBySize[launch.size, default: SizeStats()].perfect += 1
                next.noOpPerfectByKey[launchKey, default: 0] += 1
            }
        }

        if let fastest = next.fastestFinish[launch.size] {
            next.fastestFinish[launch.size] = min(fastest, seconds)
        } else {
            next.fastestFinish[launch.size] = seconds
        }

        if countsForBestTime {
            let key = "\(launch.size)-\(launch.difficulty.rawValue)"
            if let best = next.bestSeconds[key] {
                next.bestSeconds[key] = min(best, seconds)
            } else {
                next.bestSeconds[key] = seconds
            }
        }

        if launch.isDaily {
            let today = DayStamp.string()
            if next.lastDailyDay != today {
                if let last = next.lastDailyDay, DayStamp.isYesterday(last) {
                    next.currentStreak += 1
                } else {
                    next.currentStreak = 1
                }
                next.bestStreak = max(next.bestStreak, next.currentStreak)
                next.lastDailyDay = today
                next.dailySolved += 1
            }
            if countsForBestTime {
                if let best = next.bestDailySeconds {
                    next.bestDailySeconds = min(best, seconds)
                } else {
                    next.bestDailySeconds = seconds
                }
            }
        }

        store(next)
    }

    func reset() {
        store(PlayerRecord())
    }

    private func store(_ next: PlayerRecord) {
        record = next
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: storageKey)
        }
    }

    static var preview: PlayerStats {
        PlayerStats(defaults: UserDefaults(suiteName: "Mathdoku.Preview") ?? .standard)
    }
}
