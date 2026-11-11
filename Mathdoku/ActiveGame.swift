//
//  ActiveGame.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/8/26.
//

import Foundation
import Observation

struct SavedNoteChange: Codable, Equatable {
    var row: Int
    var column: Int
    var notes: Set<Int>
}

struct SavedMove: Codable, Equatable {
    var row: Int
    var column: Int
    var value: Int?
    var notes: Set<Int>
    /// Notes removed from other cells in the row and column when this digit was placed.
    var clearedNotes: [SavedNoteChange]

    init(
        row: Int,
        column: Int,
        value: Int?,
        notes: Set<Int>,
        clearedNotes: [SavedNoteChange] = []
    ) {
        self.row = row
        self.column = column
        self.value = value
        self.notes = notes
        self.clearedNotes = clearedNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        row = try container.decode(Int.self, forKey: .row)
        column = try container.decode(Int.self, forKey: .column)
        value = try container.decodeIfPresent(Int.self, forKey: .value)
        notes = try container.decode(Set<Int>.self, forKey: .notes)
        clearedNotes = try container.decodeIfPresent([SavedNoteChange].self, forKey: .clearedNotes) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(row, forKey: .row)
        try container.encode(column, forKey: .column)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encode(notes, forKey: .notes)
        try container.encode(clearedNotes, forKey: .clearedNotes)
    }

    private enum CodingKeys: String, CodingKey {
        case row, column, value, notes, clearedNotes
    }
}

struct SavedGame: Codable {
    var size: Int
    var difficulty: Difficulty
    var seed: UInt64?
    var isDaily: Bool
    var id: UInt64
    var puzzle: Puzzle
    var entries: [[Int?]]
    var notes: [[Set<Int>]]
    var selection: CellIndex?
    var undo: [SavedMove]
    var notesMode: Bool
    var usedHint: Bool
    var elapsedSeconds: Int

    var launch: GameLaunch {
        GameLaunch(size: size, difficulty: difficulty, seed: seed, isDaily: isDaily, id: id)
    }

    var summaryLine: String {
        let clock = elapsedSeconds > 0 ? " · \(Self.clock(elapsedSeconds))" : ""
        if isDaily {
            return "Today\(clock)"
        }
        return "\(size)\u{00D7}\(size) · \(difficulty.title)\(clock)"
    }

    var isTodayDaily: Bool {
        isDaily && seed == DayStamp.seed()
    }

    func matches(_ launch: GameLaunch) -> Bool {
        if id == launch.id { return true }
        return isDaily && launch.isDaily && seed == launch.seed
    }

    var isPlayable: Bool {
        guard puzzle.size == size,
              puzzle.solution.count == size,
              puzzle.solution.allSatisfy({ $0.count == size }),
              entries.count == size,
              notes.count == size,
              entries.allSatisfy({ $0.count == size }),
              notes.allSatisfy({ $0.count == size }),
              puzzle.cages.allSatisfy({ cage in
                  puzzle.cages.indices.contains(cage.id) && cage.cells.allSatisfy { cell in
                      cell.row >= 0 && cell.column >= 0 && cell.row < size && cell.column < size
                  }
              })
        else { return false }
        return !MathdokuRules.analyze(entries: entries, puzzle: puzzle).isSolved
    }

    private static func clock(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}

@Observable
final class ActiveGame {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey = "mathdoku.activeGame"

    private(set) var game: SavedGame?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(SavedGame.self, from: data),
              decoded.isPlayable
        else {
            game = nil
            if defaults.data(forKey: storageKey) != nil {
                defaults.removeObject(forKey: storageKey)
            }
            return
        }
        game = decoded
    }

    func save(_ game: SavedGame) {
        guard game.isPlayable else {
            clear()
            return
        }
        self.game = game
        if let data = try? JSONEncoder().encode(game) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func clear() {
        game = nil
        defaults.removeObject(forKey: storageKey)
    }

    static var preview: ActiveGame {
        let name = "Mathdoku.Preview.ActiveGame"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return ActiveGame(defaults: defaults)
    }
}
