//
//  Puzzle.swift
//  KenKen
//
//  Created by Logan Jasin on 11/7/26.
//

import Foundation

nonisolated struct CellIndex: Hashable, Sendable {
    var row: Int
    var column: Int
}

nonisolated enum Difficulty: String, CaseIterable, Identifiable, Sendable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }

    var detail: String {
        switch self {
        case .easy: "Small cages, mostly sums and products"
        case .medium: "A mix of cage sizes and operations"
        case .hard: "Mostly pairs, with subtraction and division"
        }
    }

    /// Largest cage the generator will grow for this difficulty.
    var maxCageSize: Int {
        switch self {
        case .easy: 2
        case .medium: 3
        case .hard: 2
        }
    }

    /// Out of ten new cages, how many are forced to a single cell.
    var singleBias: Int {
        switch self {
        case .easy: 2
        case .medium: 1
        case .hard: 0
        }
    }
}

nonisolated enum CageOperation: String, Sendable {
    case add
    case subtract
    case multiply
    case divide

    var symbol: String {
        switch self {
        case .add: "+"
        case .subtract: "\u{2212}"
        case .multiply: "\u{00D7}"
        case .divide: "\u{00F7}"
        }
    }
}

nonisolated struct Cage: Identifiable, Sendable {
    let id: Int
    let cells: [CellIndex]
    let operation: CageOperation?
    let target: Int

    var clue: String {
        guard let operation else { return "\(target)" }
        return "\(target)\(operation.symbol)"
    }
}

nonisolated struct Puzzle: Sendable {
    let size: Int
    let cages: [Cage]
    let solution: [[Int]]
    let cageIDs: [[Int]]
    let clues: [CellIndex: String]

    init(size: Int, cages: [Cage], solution: [[Int]]) {
        self.size = size
        self.cages = cages
        self.solution = solution

        var ids = Array(repeating: Array(repeating: 0, count: size), count: size)
        var clueLabels: [CellIndex: String] = [:]
        for cage in cages {
            for cell in cage.cells {
                ids[cell.row][cell.column] = cage.id
            }
            if let anchor = Self.anchor(of: cage) {
                clueLabels[anchor] = cage.clue
            }
        }
        cageIDs = ids
        clues = clueLabels
    }

    private static func anchor(of cage: Cage) -> CellIndex? {
        cage.cells.min { lhs, rhs in
            lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
        }
    }
}

nonisolated struct BoardAnalysis: Equatable, Sendable {
    var duplicates: Set<CellIndex>
    var brokenCageIDs: Set<Int>
    var filledCount: Int
    var isSolved: Bool

    static let empty = BoardAnalysis(
        duplicates: [],
        brokenCageIDs: [],
        filledCount: 0,
        isSolved: false
    )
}

nonisolated enum KenKenRules {
    static func isSatisfied(values: [Int], operation: CageOperation?, target: Int) -> Bool {
        guard !values.isEmpty else { return false }

        switch operation {
        case nil:
            return values.count == 1 && values[0] == target
        case .add:
            return values.reduce(0, +) == target
        case .multiply:
            return values.reduce(1, *) == target
        case .subtract:
            guard values.count == 2 else { return false }
            return abs(values[0] - values[1]) == target
        case .divide:
            guard values.count == 2 else { return false }
            let high = max(values[0], values[1])
            let low = min(values[0], values[1])
            return low > 0 && high % low == 0 && high / low == target
        }
    }

    static func analyze(entries: [[Int?]], puzzle: Puzzle) -> BoardAnalysis {
        let size = puzzle.size
        var duplicates = Set<CellIndex>()
        var filledCount = 0

        for row in 0..<size {
            var seen: [Int: CellIndex] = [:]
            for column in 0..<size {
                guard let value = entries[row][column] else { continue }
                filledCount += 1
                let cell = CellIndex(row: row, column: column)
                if let previous = seen[value] {
                    duplicates.insert(previous)
                    duplicates.insert(cell)
                } else {
                    seen[value] = cell
                }
            }
        }

        for column in 0..<size {
            var seen: [Int: CellIndex] = [:]
            for row in 0..<size {
                guard let value = entries[row][column] else { continue }
                let cell = CellIndex(row: row, column: column)
                if let previous = seen[value] {
                    duplicates.insert(previous)
                    duplicates.insert(cell)
                } else {
                    seen[value] = cell
                }
            }
        }

        var brokenCageIDs = Set<Int>()
        for cage in puzzle.cages {
            var values: [Int] = []
            values.reserveCapacity(cage.cells.count)
            for cell in cage.cells {
                guard let value = entries[cell.row][cell.column] else {
                    values = []
                    break
                }
                values.append(value)
            }
            guard values.count == cage.cells.count else { continue }
            if !isSatisfied(values: values, operation: cage.operation, target: cage.target) {
                brokenCageIDs.insert(cage.id)
            }
        }

        let isSolved = filledCount == size * size && duplicates.isEmpty && brokenCageIDs.isEmpty
        return BoardAnalysis(
            duplicates: duplicates,
            brokenCageIDs: brokenCageIDs,
            filledCount: filledCount,
            isSolved: isSolved
        )
    }

    static func solutionIsValid(_ puzzle: Puzzle) -> Bool {
        let entries = puzzle.solution.map { row in row.map(Optional.some) }
        return analyze(entries: entries, puzzle: puzzle).isSolved
    }
}

enum DayStamp {
    static func string(from date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func seed(from date: Date = .now, calendar: Calendar = .current) -> UInt64 {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = UInt64(parts.year ?? 0)
        let month = UInt64(parts.month ?? 0)
        let day = UInt64(parts.day ?? 0)
        return year * 10_000 + month * 100 + day
    }

    static func isYesterday(
        _ stamp: String,
        relativeTo date: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let pieces = stamp.split(separator: "-")
        guard pieces.count == 3,
              let year = Int(pieces[0]),
              let month = Int(pieces[1]),
              let day = Int(pieces[2]),
              let stamped = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))
        else { return false }
        return calendar.isDate(stamped, inSameDayAs: yesterday)
    }
}
