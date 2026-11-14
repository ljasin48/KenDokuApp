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

struct SavedComboDismissal: Codable, Equatable {
    var cageID: Int
    var digits: [Int]
}

struct SavedComboReset: Codable, Equatable {
    var cageID: Int
    var combos: [CageCombo]
}

struct SavedMove: Codable, Equatable {
    var row: Int
    var column: Int
    var value: Int?
    var notes: Set<Int>
    /// Notes removed from other cells in the row and column when this digit was placed.
    var clearedNotes: [SavedNoteChange]
    /// A cell-group combination removed from the possibility list, restored by undo.
    var comboDismissal: SavedComboDismissal?
    /// Combinations put back by Reset, so undo can remove them again.
    var comboReset: SavedComboReset?

    init(
        row: Int,
        column: Int,
        value: Int?,
        notes: Set<Int>,
        clearedNotes: [SavedNoteChange] = [],
        comboDismissal: SavedComboDismissal? = nil,
        comboReset: SavedComboReset? = nil
    ) {
        self.row = row
        self.column = column
        self.value = value
        self.notes = notes
        self.clearedNotes = clearedNotes
        self.comboDismissal = comboDismissal
        self.comboReset = comboReset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        row = try container.decode(Int.self, forKey: .row)
        column = try container.decode(Int.self, forKey: .column)
        value = try container.decodeIfPresent(Int.self, forKey: .value)
        notes = try container.decode(Set<Int>.self, forKey: .notes)
        clearedNotes = try container.decodeIfPresent([SavedNoteChange].self, forKey: .clearedNotes) ?? []
        comboDismissal = try container.decodeIfPresent(SavedComboDismissal.self, forKey: .comboDismissal)
        comboReset = try container.decodeIfPresent(SavedComboReset.self, forKey: .comboReset)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(row, forKey: .row)
        try container.encode(column, forKey: .column)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encode(notes, forKey: .notes)
        try container.encode(clearedNotes, forKey: .clearedNotes)
        try container.encodeIfPresent(comboDismissal, forKey: .comboDismissal)
        try container.encodeIfPresent(comboReset, forKey: .comboReset)
    }

    private enum CodingKeys: String, CodingKey {
        case row, column, value, notes, clearedNotes, comboDismissal, comboReset
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
    var madeError: Bool
    var elapsedSeconds: Int
    /// Combinations the player removed, keyed by cage id.
    var dismissedCombos: [Int: [CageCombo]]
    /// True after the player enters a number or note. Opening the puzzle does not count.
    var countedAsPlayed: Bool
    /// Puzzle-timer seconds already added to the lifetime total.
    var creditedSeconds: Int

    init(
        size: Int,
        difficulty: Difficulty,
        seed: UInt64?,
        isDaily: Bool,
        id: UInt64,
        puzzle: Puzzle,
        entries: [[Int?]],
        notes: [[Set<Int>]],
        selection: CellIndex?,
        undo: [SavedMove],
        notesMode: Bool,
        usedHint: Bool,
        madeError: Bool = false,
        elapsedSeconds: Int,
        dismissedCombos: [Int: [CageCombo]] = [:],
        countedAsPlayed: Bool = false,
        creditedSeconds: Int = 0
    ) {
        self.size = size
        self.difficulty = difficulty
        self.seed = seed
        self.isDaily = isDaily
        self.id = id
        self.puzzle = puzzle
        self.entries = entries
        self.notes = notes
        self.selection = selection
        self.undo = undo
        self.notesMode = notesMode
        self.usedHint = usedHint
        self.madeError = madeError
        self.elapsedSeconds = elapsedSeconds
        self.dismissedCombos = dismissedCombos
        self.countedAsPlayed = countedAsPlayed
        self.creditedSeconds = creditedSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        size = try container.decode(Int.self, forKey: .size)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
        isDaily = try container.decode(Bool.self, forKey: .isDaily)
        id = try container.decode(UInt64.self, forKey: .id)
        puzzle = try container.decode(Puzzle.self, forKey: .puzzle)
        entries = try container.decode([[Int?]].self, forKey: .entries)
        notes = try container.decode([[Set<Int>]].self, forKey: .notes)
        selection = try container.decodeIfPresent(CellIndex.self, forKey: .selection)
        undo = try container.decode([SavedMove].self, forKey: .undo)
        notesMode = try container.decode(Bool.self, forKey: .notesMode)
        usedHint = try container.decode(Bool.self, forKey: .usedHint)
        madeError = try container.decodeIfPresent(Bool.self, forKey: .madeError) ?? false
        elapsedSeconds = try container.decode(Int.self, forKey: .elapsedSeconds)
        dismissedCombos = try container.decodeIfPresent([Int: [CageCombo]].self, forKey: .dismissedCombos) ?? [:]
        countedAsPlayed = try container.decodeIfPresent(Bool.self, forKey: .countedAsPlayed) ?? true
        creditedSeconds = try container.decodeIfPresent(Int.self, forKey: .creditedSeconds) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encode(isDaily, forKey: .isDaily)
        try container.encode(id, forKey: .id)
        try container.encode(puzzle, forKey: .puzzle)
        try container.encode(entries, forKey: .entries)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(selection, forKey: .selection)
        try container.encode(undo, forKey: .undo)
        try container.encode(notesMode, forKey: .notesMode)
        try container.encode(usedHint, forKey: .usedHint)
        try container.encode(madeError, forKey: .madeError)
        try container.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try container.encode(dismissedCombos, forKey: .dismissedCombos)
        try container.encode(countedAsPlayed, forKey: .countedAsPlayed)
        try container.encode(creditedSeconds, forKey: .creditedSeconds)
    }

    private enum CodingKeys: String, CodingKey {
        case size, difficulty, seed, isDaily, id, puzzle, entries, notes, selection, undo
        case notesMode, usedHint, madeError, elapsedSeconds, dismissedCombos, countedAsPlayed, creditedSeconds
    }

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
