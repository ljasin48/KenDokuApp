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
    }

    private enum CodingKeys: String, CodingKey {
        case solved, dailySolved, currentStreak, bestStreak, lastDailyDay, bestDailySeconds, bestSeconds
        case played, completed, perfect, bySize
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

    func recordStart(size: Int) {
        var next = record
        next.played += 1
        next.bySize[size, default: SizeStats()].played += 1
        store(next)
    }

    func recordWin(seconds: Int, launch: GameLaunch, countsForBestTime: Bool, perfect: Bool) {
        var next = record
        next.solved += 1
        next.completed += 1
        next.bySize[launch.size, default: SizeStats()].completed += 1
        if perfect {
            next.perfect += 1
            next.bySize[launch.size, default: SizeStats()].perfect += 1
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
