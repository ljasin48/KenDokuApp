//
//  PlayerStats.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/7/26.
//

import Foundation
import Observation

struct PlayerRecord: Codable, Equatable {
    var solved = 0
    var dailySolved = 0
    var currentStreak = 0
    var bestStreak = 0
    var lastDailyDay: String?
    var bestSeconds: [String: Int] = [:]
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

    func recordWin(seconds: Int, launch: GameLaunch, countsForBestTime: Bool) {
        var next = record
        next.solved += 1

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
        }

        record = next
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: storageKey)
        }
    }

    static var preview: PlayerStats {
        PlayerStats(defaults: UserDefaults(suiteName: "Mathdoku.Preview") ?? .standard)
    }
}
