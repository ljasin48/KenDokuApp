//
//  Puzzle.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/7/26.
//

import Foundation

nonisolated struct CellIndex: Hashable, Sendable, Codable {
    var row: Int
    var column: Int
}

nonisolated enum Difficulty: String, CaseIterable, Identifiable, Sendable, Codable {
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

    /// Largest cage the generator will place for this difficulty.
    var maxCageSize: Int {
        switch self {
        case .easy: 3
        case .medium: 4
        case .hard: 5
        }
    }

    /// How often a cage of this size is chosen. The middle of the allowed range is the most common.
    func cageWeight(for size: Int) -> Int {
        switch (self, size) {
        case (.easy, 2), (.easy, 3): 3
        case (.medium, 2): 2
        case (.medium, 3): 4
        case (.medium, 4): 2
        case (.hard, 2): 2
        case (.hard, 3): 4
        case (.hard, 4): 3
        case (.hard, 5): 1
        default: 0
        }
    }

    /// Out of ten cages of this size, how many must bend. Easy stays straight. A hard cage of 5 always bends.
    func bendChance(for size: Int) -> Int {
        guard size >= 3 else { return 0 }
        switch self {
        case .easy: return 0
        case .medium: return 3
        case .hard: return size >= 5 ? 10 : 6
        }
    }
}

nonisolated enum CageOperation: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case add
    case subtract
    case multiply
    case divide

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .add: "+"
        case .subtract: "\u{2212}"
        case .multiply: "\u{00D7}"
        case .divide: "\u{00F7}"
        }
    }

    var name: String {
        switch self {
        case .add: "Addition"
        case .subtract: "Subtraction"
        case .multiply: "Multiplication"
        case .divide: "Division"
        }
    }

    /// Subtraction and division are only defined for a pair of cells.
    var allowsLargerCages: Bool {
        switch self {
        case .add, .multiply: true
        case .subtract, .divide: false
        }
    }
}

/// Which operations a puzzle may use, and whether those symbols are shown.
nonisolated struct OperatorRules: Sendable, Equatable, Hashable, Codable {
    var add: Bool
    var subtract: Bool
    var multiply: Bool
    var divide: Bool
    var hidesOperators: Bool

    static let standard = OperatorRules(
        add: true,
        subtract: true,
        multiply: true,
        divide: true,
        hidesOperators: false
    )

    func allows(_ operation: CageOperation) -> Bool {
        switch operation {
        case .add: add
        case .subtract: subtract
        case .multiply: multiply
        case .divide: divide
        }
    }

    mutating func set(_ operation: CageOperation, enabled: Bool) {
        switch operation {
        case .add: add = enabled
        case .subtract: subtract = enabled
        case .multiply: multiply = enabled
        case .divide: divide = enabled
        }
    }

    var enabledOperations: [CageOperation] {
        CageOperation.allCases.filter(allows)
    }

    /// Division alone cannot fill a board. Many pairs do not divide evenly, so those cages collapse into single cells.
    var isDivideOnly: Bool {
        divide && !add && !subtract && !multiply
    }

    /// At least one operation has to stay available, and division cannot be the only one.
    var normalized: OperatorRules {
        if enabledOperations.isEmpty {
            var restored = OperatorRules.standard
            restored.hidesOperators = hidesOperators
            return restored
        }
        guard isDivideOnly else { return self }
        var repaired = self
        repaired.add = true
        return repaired
    }

    func operations(forCellCount count: Int) -> [CageOperation] {
        enabledOperations.filter { operation in
            count == 2 || operation.allowsLargerCages
        }
    }
}

nonisolated struct Cage: Identifiable, Sendable, Codable {
    let id: Int
    let cells: [CellIndex]
    let operation: CageOperation?
    let target: Int

    func clue(hidingOperation: Bool) -> String {
        guard let operation, !hidingOperation else { return "\(target)" }
        return "\(target)\(operation.symbol)"
    }
}

nonisolated struct Puzzle: Sendable, Codable {
    let size: Int
    let cages: [Cage]
    let solution: [[Int]]
    let cageIDs: [[Int]]
    let clues: [CellIndex: String]
    let rules: OperatorRules

    init(size: Int, cages: [Cage], solution: [[Int]], rules: OperatorRules = .standard) {
        self.size = size
        self.cages = cages
        self.solution = solution
        self.rules = rules

        var ids = Array(repeating: Array(repeating: 0, count: size), count: size)
        var clueLabels: [CellIndex: String] = [:]
        for cage in cages {
            for cell in cage.cells {
                ids[cell.row][cell.column] = cage.id
            }
            if let anchor = Self.anchor(of: cage) {
                clueLabels[anchor] = cage.clue(hidingOperation: rules.hidesOperators)
            }
        }
        cageIDs = ids
        clues = clueLabels
    }

    private enum CodingKeys: String, CodingKey {
        case size, cages, solution, rules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let size = try container.decode(Int.self, forKey: .size)
        let cages = try container.decode([Cage].self, forKey: .cages)
        let solution = try container.decode([[Int]].self, forKey: .solution)
        let rules = try container.decode(OperatorRules.self, forKey: .rules)
        self.init(size: size, cages: cages, solution: solution, rules: rules)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(cages, forKey: .cages)
        try container.encode(solution, forKey: .solution)
        try container.encode(rules, forKey: .rules)
    }

    /// The same cages with the corner symbol shown or hidden. Generation does not depend on this flag.
    func shown(hidingOperators: Bool) -> Puzzle {
        guard rules.hidesOperators != hidingOperators else { return self }
        var shownRules = rules
        shownRules.hidesOperators = hidingOperators
        return Puzzle(size: size, cages: cages, solution: solution, rules: shownRules)
    }

    /// A one-cell cage is fixed to its target, so that number can be filled in immediately.
    func isGiven(_ cell: CellIndex) -> Bool {
        guard cell.row >= 0, cell.column >= 0, cell.row < size, cell.column < size else { return false }
        return cages[cageIDs[cell.row][cell.column]].cells.count == 1
    }

    func startingEntries() -> [[Int?]] {
        var grid = Array(repeating: Array(repeating: Optional<Int>.none, count: size), count: size)
        for cage in cages where cage.cells.count == 1 {
            for cell in cage.cells {
                grid[cell.row][cell.column] = cage.target
            }
        }
        return grid
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

/// Which entered numbers are marked while a puzzle is in play.
nonisolated enum MistakeHighlight: String, CaseIterable, Identifiable, Sendable {
    /// No cells are marked.
    case off
    /// A finished cell group whose numbers miss its target.
    case arithmetic
    /// An entered number that differs from the solution in that cell.
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .arithmetic: "Arithmetic only"
        case .all: "All"
        }
    }

    var detail: String {
        switch self {
        case .off:
            "No cells are marked."
        case .arithmetic:
            "Mark a finished cell group when its numbers miss the target."
        case .all:
            "Mark a number that does not match the solution in that cell."
        }
    }

    func marks(
        _ cell: CellIndex,
        entries: [[Int?]],
        puzzle: Puzzle,
        analysis: BoardAnalysis
    ) -> Bool {
        switch self {
        case .off:
            return false
        case .arithmetic:
            guard cell.row >= 0, cell.column >= 0,
                  cell.row < puzzle.size, cell.column < puzzle.size else { return false }
            let cageID = puzzle.cageIDs[cell.row][cell.column]
            return analysis.brokenCageIDs.contains(cageID)
        case .all:
            guard cell.row >= 0, cell.column >= 0,
                  cell.row < entries.count, cell.column < entries[cell.row].count,
                  cell.row < puzzle.solution.count, cell.column < puzzle.solution[cell.row].count,
                  let value = entries[cell.row][cell.column] else { return false }
            return value != puzzle.solution[cell.row][cell.column]
        }
    }
}

/// One way to fill a cell group. `digits` on a stored dismissal are sorted ascending.
nonisolated struct CageCombo: Hashable, Codable, Sendable {
    var digits: [Int]

    /// Same numbers, smallest first. Placements that differ only by cell order match.
    var canonical: CageCombo {
        CageCombo(digits: digits.sorted())
    }
}

nonisolated enum MathdokuRules {
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

    static func orderedCells(_ cells: [CellIndex]) -> [CellIndex] {
        cells.sorted { lhs, rhs in
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.column < rhs.column
        }
    }

    /// Combinations that fit this group and the numbers already entered, including a wrong digit.
    /// The solution is not consulted.
    /// Pass nil for `operations` to use only this group's own operation.
    /// When the symbol is hidden, pass every operation the rules allow for this cell count.
    /// The list is their union, so it does not reveal which operation the group uses.
    static func combinations(
        cage: Cage,
        entries: [[Int?]],
        size: Int,
        operations: [CageOperation]? = nil
    ) -> [CageCombo] {
        let cells = orderedCells(cage.cells)
        let length = cells.count
        guard length > 0, entries.count == size, entries.allSatisfy({ $0.count == size }) else { return [] }
        guard cells.allSatisfy({ $0.row >= 0 && $0.column >= 0 && $0.row < size && $0.column < size }) else {
            return []
        }

        let tried: [CageOperation?]
        if let operations {
            guard !operations.isEmpty else { return [] }
            tried = operations.map { Optional($0) }
        } else {
            tried = [cage.operation]
        }

        var pins = [Int?](repeating: nil, count: length)
        for (index, cell) in cells.enumerated() {
            guard let value = entries[cell.row][cell.column] else { continue }
            guard (1...size).contains(value) else { return [] }
            pins[index] = value
        }

        let cageCells = Set(cells)
        var rowUsed = [Int](repeating: 0, count: size)
        var columnUsed = [Int](repeating: 0, count: size)
        for row in 0..<size {
            for column in 0..<size {
                let cell = CellIndex(row: row, column: column)
                guard !cageCells.contains(cell), let value = entries[row][column], (1...size).contains(value) else {
                    continue
                }
                rowUsed[row] |= 1 << value
                columnUsed[column] |= 1 << value
            }
        }

        var values = [Int](repeating: 0, count: length)
        var found: [CageCombo] = []
        var seen = Set<CageCombo>()

        func walk(_ index: Int, sum: Int, product: Int, operation: CageOperation?) {
            if index == length {
                if isSatisfied(values: values, operation: operation, target: cage.target) {
                    let combo = CageCombo(digits: values)
                    if seen.insert(combo).inserted {
                        found.append(combo)
                    }
                }
                return
            }
            let cell = cells[index]
            let remain = length - index - 1
            let choices = pins[index].map { [$0] } ?? Array(1...size)
            for value in choices {
                let bit = 1 << value
                if rowUsed[cell.row] & bit != 0 || columnUsed[cell.column] & bit != 0 {
                    continue
                }
                if operation == .add {
                    let next = sum + value
                    if next > cage.target || next + remain > cage.target || next + remain * size < cage.target {
                        continue
                    }
                } else if operation == .multiply {
                    let next = product * value
                    if next > cage.target || (cage.target % next) != 0 {
                        continue
                    }
                }
                values[index] = value
                rowUsed[cell.row] |= bit
                columnUsed[cell.column] |= bit
                walk(
                    index + 1,
                    sum: operation == .add ? sum + value : sum,
                    product: operation == .multiply ? product * value : product,
                    operation: operation
                )
                rowUsed[cell.row] &= ~bit
                columnUsed[cell.column] &= ~bit
            }
        }

        for operation in tried {
            walk(0, sum: 0, product: 1, operation: operation)
        }
        return found
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
            if !cageIsSatisfied(values: values, cage: cage) {
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

    static func cageIsSatisfied(values: [Int], cage: Cage) -> Bool {
        if cage.operation == nil || values.count <= 1 {
            return values.count == 1 && values.first == cage.target
        }
        return isSatisfied(values: values, operation: cage.operation, target: cage.target)
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
