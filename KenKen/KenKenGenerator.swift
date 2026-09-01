//
//  KenKenGenerator.swift
//  KenKen
//
//  Created by Logan Jasin on 11/7/26.
//

import Foundation

/// Deterministic generator so the daily board is the same all day.
nonisolated struct SplitMix64: RandomNumberGenerator, Sendable {
    var state: UInt64

    init(state: UInt64) {
        self.state = state == 0 ? 0xA5A5_5A5A_1234_5678 : state
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

nonisolated enum KenKenGenerator {
    static func generate(size: Int, difficulty: Difficulty, seed: UInt64? = nil) -> Puzzle {
        if let seed {
            var generator = SplitMix64(state: seed)
            return generate(size: size, difficulty: difficulty, rng: &generator)
        }
        var generator = SystemRandomNumberGenerator()
        return generate(size: size, difficulty: difficulty, rng: &generator)
    }

    static func generate<R: RandomNumberGenerator>(
        size: Int,
        difficulty: Difficulty,
        rng: inout R
    ) -> Puzzle {
        let profiles: [(maxSize: Int, singleBias: Int)] = [
            (difficulty.maxCageSize, difficulty.singleBias),
            (min(difficulty.maxCageSize, 2), difficulty.singleBias + 2),
            (2, 4)
        ]

        for profile in profiles {
            for _ in 0..<16 {
                let solution = latinSquare(size: size, rng: &rng)
                let cages = cages(
                    from: solution,
                    maxSize: profile.maxSize,
                    singleBias: profile.singleBias,
                    difficulty: difficulty,
                    rng: &rng
                )
                let puzzle = Puzzle(size: size, cages: cages, solution: solution)
                guard KenKenRules.solutionIsValid(puzzle) else { continue }

                // Stop after a second solution. A unique board is the one we built.
                let outcome = KenKenSolver.countSolutions(of: puzzle, limit: 2, nodeLimit: 12_000)
                if outcome.count == 1 && !outcome.reachedLimit {
                    return puzzle
                }
            }
        }

        return revealedPuzzle(size: size, rng: &rng)
    }

    private static func latinSquare<R: RandomNumberGenerator>(size: Int, rng: inout R) -> [[Int]] {
        var grid = (0..<size).map { row in
            (0..<size).map { column in
                (row + column) % size + 1
            }
        }
        let symbols = (1...size).shuffled(using: &rng)
        grid = grid.map { row in row.map { symbols[$0 - 1] } }
        grid.shuffle(using: &rng)
        let columns = (0..<size).shuffled(using: &rng)
        return grid.map { row in columns.map { row[$0] } }
    }

    private static func cages<R: RandomNumberGenerator>(
        from solution: [[Int]],
        maxSize: Int,
        singleBias: Int,
        difficulty: Difficulty,
        rng: inout R
    ) -> [Cage] {
        let size = solution.count
        var free = (0..<size).flatMap { row in
            (0..<size).map { CellIndex(row: row, column: $0) }
        }
        var built: [Cage] = []

        while !free.isEmpty {
            let start = Int.random(in: 0..<free.count, using: &rng)
            var cells = [free.remove(at: start)]
            let grow = Int.random(in: 0..<10, using: &rng) >= singleBias
            let targetCount = grow ? Int.random(in: 2...max(2, maxSize), using: &rng) : 1

            while cells.count < targetCount {
                let adjacent = neighbors(of: cells, free: free, size: size)
                if adjacent.isEmpty { break }
                let pick = adjacent[Int.random(in: 0..<adjacent.count, using: &rng)]
                cells.append(pick)
                free.removeAll { $0 == pick }
            }

            built.append(
                makeCage(id: built.count, cells: cells, solution: solution, difficulty: difficulty, rng: &rng)
            )
        }

        return built
    }

    private static func neighbors(of cells: [CellIndex], free: [CellIndex], size: Int) -> [CellIndex] {
        let open = Set(free)
        var adjacent: [CellIndex] = []
        var seen = Set<CellIndex>()
        let steps = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        for cell in cells {
            for step in steps {
                let next = CellIndex(row: cell.row + step.0, column: cell.column + step.1)
                guard next.row >= 0, next.column >= 0, next.row < size, next.column < size else { continue }
                guard open.contains(next), seen.insert(next).inserted else { continue }
                adjacent.append(next)
            }
        }
        return adjacent
    }

    private static func makeCage<R: RandomNumberGenerator>(
        id: Int,
        cells: [CellIndex],
        solution: [[Int]],
        difficulty: Difficulty,
        rng: inout R
    ) -> Cage {
        let values = cells.map { solution[$0.row][$0.column] }
        if values.count == 1 {
            return Cage(id: id, cells: cells, operation: nil, target: values[0])
        }

        var options: [(CageOperation, Int)] = [
            (.add, values.reduce(0, +)),
            (.multiply, values.reduce(1, *))
        ]
        if values.count == 2 {
            options.append((.subtract, abs(values[0] - values[1])))
            let high = max(values[0], values[1])
            let low = min(values[0], values[1])
            if low > 0 && high % low == 0 {
                options.append((.divide, high / low))
            }
        }

        var weighted: [(CageOperation, Int)] = []
        for option in options {
            let copies = weight(option.0, difficulty: difficulty, cellCount: values.count)
            if copies > 0 {
                weighted.append(contentsOf: Array(repeating: option, count: copies))
            }
        }
        let chosen = weighted.randomElement(using: &rng) ?? (.add, values.reduce(0, +))
        return Cage(id: id, cells: cells, operation: chosen.0, target: chosen.1)
    }

    private static func weight(_ operation: CageOperation, difficulty: Difficulty, cellCount: Int) -> Int {
        if cellCount > 2 {
            switch (difficulty, operation) {
            case (.easy, .add): return 5
            case (.easy, .multiply): return 1
            case (.medium, .add): return 3
            case (.medium, .multiply): return 2
            case (.hard, .add), (.hard, .multiply): return 1
            default: return 0
            }
        }

        switch (difficulty, operation) {
        case (.easy, .add): return 5
        case (.easy, .multiply): return 4
        case (.easy, .subtract), (.easy, .divide): return 1
        case (.medium, .add), (.medium, .multiply): return 3
        case (.medium, .subtract), (.medium, .divide): return 2
        case (.hard, .add): return 1
        case (.hard, .multiply): return 2
        case (.hard, .subtract), (.hard, .divide): return 4
        }
    }

    /// Every cell is its own cage. That board is unique, so generation can always finish.
    private static func revealedPuzzle<R: RandomNumberGenerator>(size: Int, rng: inout R) -> Puzzle {
        let solution = latinSquare(size: size, rng: &rng)
        var cages: [Cage] = []
        for row in 0..<size {
            for column in 0..<size {
                let cell = CellIndex(row: row, column: column)
                cages.append(
                    Cage(id: cages.count, cells: [cell], operation: nil, target: solution[row][column])
                )
            }
        }
        return Puzzle(size: size, cages: cages, solution: solution)
    }
}

nonisolated enum KenKenSolver {
    struct Outcome: Equatable, Sendable {
        var count: Int
        var reachedLimit: Bool
    }

    static func countSolutions(of puzzle: Puzzle, limit: Int = 2, nodeLimit: Int = 12_000) -> Outcome {
        var search = Search(puzzle: puzzle, limit: limit, nodeLimit: nodeLimit)
        search.explore()
        return Outcome(count: search.count, reachedLimit: search.reachedLimit)
    }

    private struct Search {
        let puzzle: Puzzle
        let limit: Int
        let nodeLimit: Int
        var grid: [[Int]]
        var rowMask: [Int]
        var columnMask: [Int]
        var count = 0
        var nodes = 0
        var reachedLimit = false

        init(puzzle: Puzzle, limit: Int, nodeLimit: Int) {
            self.puzzle = puzzle
            self.limit = limit
            self.nodeLimit = nodeLimit
            grid = Array(repeating: Array(repeating: 0, count: puzzle.size), count: puzzle.size)
            rowMask = Array(repeating: 0, count: puzzle.size)
            columnMask = Array(repeating: 0, count: puzzle.size)
        }

        struct Choice {
            var cell: CellIndex
            var values: [Int]
        }

        mutating func explore() {
            if count >= limit {
                return
            }
            if nodes >= nodeLimit {
                reachedLimit = true
                return
            }
            nodes += 1

            guard let choice = nextChoice() else {
                count += 1
                return
            }
            if choice.values.isEmpty {
                return
            }

            for value in choice.values {
                place(value, at: choice.cell)
                explore()
                remove(value, at: choice.cell)
                if count >= limit {
                    return
                }
                if nodes >= nodeLimit {
                    reachedLimit = true
                    return
                }
            }
        }

        mutating func nextChoice() -> Choice? {
            var best: Choice?
            for row in 0..<puzzle.size {
                for column in 0..<puzzle.size where grid[row][column] == 0 {
                    let cell = CellIndex(row: row, column: column)
                    let values = candidates(row: row, column: column)
                    if values.isEmpty {
                        return Choice(cell: cell, values: [])
                    }
                    if let current = best {
                        if values.count < current.values.count {
                            best = Choice(cell: cell, values: values)
                        }
                    } else {
                        best = Choice(cell: cell, values: values)
                    }
                }
            }
            return best
        }

        mutating func candidates(row: Int, column: Int) -> [Int] {
            let cage = puzzle.cages[puzzle.cageIDs[row][column]]
            var filled: [Int] = []
            for cell in cage.cells where !(cell.row == row && cell.column == column) {
                let value = grid[cell.row][cell.column]
                if value != 0 {
                    filled.append(value)
                }
            }
            let emptyOthers = cage.cells.count - filled.count - 1

            var allowed: [Int] = []
            for value in 1...puzzle.size {
                let bit = 1 << value
                if rowMask[row] & bit != 0 || columnMask[column] & bit != 0 {
                    continue
                }
                if allows(value, operation: cage.operation, target: cage.target, filled: filled, emptyOthers: emptyOthers) {
                    allowed.append(value)
                }
            }
            return allowed
        }

        /// Loose bounds for unfinished cages, exact checks once a cage is full.
        func allows(
            _ value: Int,
            operation: CageOperation?,
            target: Int,
            filled: [Int],
            emptyOthers: Int
        ) -> Bool {
            switch operation {
            case nil:
                return value == target
            case .add:
                let next = filled.reduce(0, +) + value
                if emptyOthers == 0 { return next == target }
                return next + emptyOthers <= target && next + emptyOthers * puzzle.size >= target
            case .multiply:
                let next = filled.reduce(1, *) * value
                if next <= 0 || next > target || target % next != 0 { return false }
                return emptyOthers > 0 || next == target
            case .subtract:
                guard let other = filled.first else { return true }
                if filled.count > 1 { return false }
                return value == other + target || value == other - target
            case .divide:
                guard let other = filled.first, target > 0 else { return filled.isEmpty }
                if filled.count > 1 { return false }
                let asLarger = other * target
                let asSmaller = other % target == 0 ? other / target : nil
                return value == asLarger || value == asSmaller
            }
        }

        mutating func place(_ value: Int, at cell: CellIndex) {
            grid[cell.row][cell.column] = value
            rowMask[cell.row] |= 1 << value
            columnMask[cell.column] |= 1 << value
        }

        mutating func remove(_ value: Int, at cell: CellIndex) {
            grid[cell.row][cell.column] = 0
            rowMask[cell.row] &= ~(1 << value)
            columnMask[cell.column] &= ~(1 << value)
        }
    }
}
