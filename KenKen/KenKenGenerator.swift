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
    static func generate(
        size: Int,
        difficulty: Difficulty,
        seed: UInt64? = nil,
        rules: OperatorRules = .standard
    ) -> Puzzle {
        let rules = rules.normalized
        if let seed {
            var generator = SplitMix64(state: seed)
            return generate(size: size, difficulty: difficulty, rules: rules, rng: &generator)
        }
        var generator = SystemRandomNumberGenerator()
        return generate(size: size, difficulty: difficulty, rules: rules, rng: &generator)
    }

    static func generate<R: RandomNumberGenerator>(
        size: Int,
        difficulty: Difficulty,
        rules: OperatorRules = .standard,
        rng: inout R
    ) -> Puzzle {
        let rules = rules.normalized
        // Subtract and divide only apply to pairs, so a ruleset without a 3-cell operation stays pairs.
        let pairOnly = rules.operations(forCellCount: 3).isEmpty
        var caps: [Int] = []
        // A pure pair pass draws an odd board as parallel dominoes with one seam. Keep it for pair-only rules.
        let searchCaps = pairOnly ? [2] : [difficulty.maxCageSize, max(3, difficulty.maxCageSize - 1)]
        for cap in searchCaps where !caps.contains(cap) {
            caps.append(cap)
        }

        var ambiguous: (Puzzle, [[[Int]]])?
        var playable: Puzzle?
        let attemptLimit = pairOnly ? 5 : 16
        let nodeLimit = pairOnly ? 4_000 : 12_000
        for maxSize in caps {
            for _ in 0..<attemptLimit {
                let solution = latinSquare(size: size, rng: &rng)
                guard let cages = cages(
                    from: solution,
                    maxSize: maxSize,
                    difficulty: difficulty,
                    rules: rules,
                    rng: &rng
                ) else { continue }
                let puzzle = Puzzle(size: size, cages: cages, solution: solution, rules: rules)
                guard KenKenRules.solutionIsValid(puzzle) else { continue }
                guard puzzle.cages.contains(where: { $0.cells.count > 1 }) else { continue }
                playable = puzzle

                // Stop after a second solution. A unique board is the one we built.
                let outcome = KenKenSolver.countSolutions(of: puzzle, limit: 2, nodeLimit: nodeLimit)
                if outcome.count == 1 && !outcome.reachedLimit {
                    return puzzle
                }
                if outcome.solutions.count >= 2, ambiguous == nil {
                    ambiguous = (puzzle, outcome.solutions)
                }
            }
        }

        if let ambiguous, let pinned = pin(ambiguous.0, solutions: ambiguous.1, difficulty: difficulty, rng: &rng) {
            return pinned
        }
        if let playable {
            return playable
        }
        return playableCover(size: size, difficulty: difficulty, rules: rules, rng: &rng)
    }

    /// Locks cells where two solutions disagree, until only one solution remains.
    private static func pin<R: RandomNumberGenerator>(
        _ puzzle: Puzzle,
        solutions: [[[Int]]],
        difficulty: Difficulty,
        rng: inout R
    ) -> Puzzle? {
        guard solutions.count >= 2 else { return nil }
        var puzzle = puzzle
        var first = solutions[0]
        var second = solutions[1]
        for _ in 0..<puzzle.size {
            guard let cell = pinCell(between: first, and: second, puzzle: puzzle) else { return nil }
            guard let split = splitOff(cell, in: puzzle, difficulty: difficulty, rng: &rng) else { return nil }
            puzzle = split
            guard KenKenRules.solutionIsValid(puzzle) else { return nil }
            let outcome = KenKenSolver.countSolutions(of: puzzle, limit: 2, nodeLimit: 12_000)
            if outcome.count == 1 && !outcome.reachedLimit {
                return puzzle
            }
            guard outcome.solutions.count >= 2 else { return nil }
            first = outcome.solutions[0]
            second = outcome.solutions[1]
        }
        return nil
    }

    private static func pinCell(between first: [[Int]], and second: [[Int]], puzzle: Puzzle) -> CellIndex? {
        var best: (cell: CellIndex, count: Int)?
        for row in 0..<puzzle.size {
            for column in 0..<puzzle.size where first[row][column] != second[row][column] {
                let cell = CellIndex(row: row, column: column)
                let cage = puzzle.cages[puzzle.cageIDs[row][column]]
                let rest = cage.cells.filter { $0 != cell }
                guard cage.cells.count >= 2, isConnected(rest) else { continue }
                if best == nil || cage.cells.count > (best?.count ?? 0) {
                    best = (cell, cage.cells.count)
                }
            }
        }
        return best?.cell
    }

    private static func splitOff<R: RandomNumberGenerator>(
        _ cell: CellIndex,
        in puzzle: Puzzle,
        difficulty: Difficulty,
        rng: inout R
    ) -> Puzzle? {
        var groups = puzzle.cages.map(\.cells)
        guard let index = groups.firstIndex(where: { $0.contains(cell) }) else { return puzzle }
        let rest = groups[index].filter { $0 != cell }
        groups.remove(at: index)
        groups.append(contentsOf: components(of: rest))
        groups.append([cell])
        return assemble(groups: groups, solution: puzzle.solution, difficulty: difficulty, rules: puzzle.rules, rng: &rng)
    }

    private static func components(of cells: [CellIndex]) -> [[CellIndex]] {
        var remaining = Set(cells)
        var parts: [[CellIndex]] = []
        while let start = remaining.min(by: isBefore) {
            remaining.remove(start)
            var stack = [start]
            var part: [CellIndex] = []
            while let cell = stack.popLast() {
                part.append(cell)
                for step in orthogonalSteps {
                    let next = CellIndex(row: cell.row + step.0, column: cell.column + step.1)
                    if remaining.remove(next) != nil {
                        stack.append(next)
                    }
                }
            }
            parts.append(part)
        }
        return parts
    }

    private static func assemble<R: RandomNumberGenerator>(
        groups: [[CellIndex]],
        solution: [[Int]],
        difficulty: Difficulty,
        rules: OperatorRules,
        rng: inout R
    ) -> Puzzle? {
        var built: [Cage] = []
        for cells in groups where !cells.isEmpty {
            guard let made = makeCages(
                startingID: built.count,
                cells: cells,
                solution: solution,
                difficulty: difficulty,
                rules: rules,
                rng: &rng
            ) else { return nil }
            built.append(contentsOf: made)
        }
        guard built.contains(where: { $0.cells.count > 1 }) else { return nil }
        return Puzzle(size: solution.count, cages: built, solution: solution, rules: rules)
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

    private static let orthogonalSteps = [(0, 1), (1, 0), (0, -1), (-1, 0)]

    /// Set iteration order is not stable across runs, and several picks consume the seeded generator.
    private static func isBefore(_ lhs: CellIndex, _ rhs: CellIndex) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }

    private static func cages<R: RandomNumberGenerator>(
        from solution: [[Int]],
        maxSize: Int,
        difficulty: Difficulty,
        rules: OperatorRules,
        rng: inout R
    ) -> [Cage]? {
        let size = solution.count
        let cap = max(2, maxSize)
        // A 3-cell cage needs addition or multiplication.
        let pairOnly = rules.operations(forCellCount: 3).isEmpty
        let groups: [[CellIndex]]
        if pairOnly || cap < 3 {
            groups = snakeCover(size: size, difficulty: difficulty, maxSize: min(cap, 2), rng: &rng)
                ?? pairCover(size: size, rng: &rng)
        } else {
            let irregular = snakeCover(size: size, difficulty: difficulty, maxSize: cap, rng: &rng)
            // An all-pair snake on an odd board is the striped seam. Tile with longer cages instead.
            if let irregular, longestCage(in: irregular) >= 3, !isSeamedPairLayout(irregular, size: size) {
                groups = irregular
            } else {
                var tiled = straightCover(size: size, rng: &rng)
                if cap >= 4 {
                    tiled = reshape(tiled, difficulty: difficulty, maxSize: cap, rng: &rng)
                }
                groups = tiled
            }
        }
        if !pairOnly && cap >= 3 && (longestCage(in: groups) < 3 || isSeamedPairLayout(groups, size: size)) {
            return nil
        }

        var built: [Cage] = []
        var covered = Set<CellIndex>()
        for cells in groups {
            let unique = cells.filter { covered.insert($0).inserted }
            guard !unique.isEmpty else { continue }
            guard let made = makeCages(
                startingID: built.count,
                cells: unique,
                solution: solution,
                difficulty: difficulty,
                rules: rules,
                rng: &rng
            ) else { return nil }
            built.append(contentsOf: made)
        }
        guard covered.count == size * size else { return nil }
        guard built.contains(where: { $0.cells.count > 1 }) else { return nil }
        return built
    }

    /// Irregular snakes. Returns nil when a restart still leaves a single cell behind.
    private static func snakeCover<R: RandomNumberGenerator>(
        size: Int,
        difficulty: Difficulty,
        maxSize: Int,
        rng: inout R
    ) -> [[CellIndex]]? {
        for _ in 0..<12 {
            var free = Set((0..<size).flatMap { row in
                (0..<size).map { CellIndex(row: row, column: $0) }
            })
            var groups: [[CellIndex]] = []
            while free.count >= 2 {
                guard let start = tightestStart(in: free, rng: &rng),
                      let shape = chosenShape(
                        from: start,
                        free: free,
                        difficulty: difficulty,
                        maxSize: maxSize,
                        rng: &rng
                      )
                else { break }
                groups.append(shape)
                free.subtract(shape)
            }
            absorbOrphans(&groups, free: &free, difficulty: difficulty, maxSize: maxSize, rng: &rng)
            if free.isEmpty {
                return groups
            }
        }
        return nil
    }

    private static func tightestStart<R: RandomNumberGenerator>(
        in free: Set<CellIndex>,
        rng: inout R
    ) -> CellIndex? {
        var best: [CellIndex] = []
        var bestNeighbors = Int.max
        for cell in free {
            var neighbors = 0
            for step in orthogonalSteps {
                let next = CellIndex(row: cell.row + step.0, column: cell.column + step.1)
                if free.contains(next) {
                    neighbors += 1
                }
            }
            guard neighbors > 0 else { continue }
            if neighbors < bestNeighbors {
                bestNeighbors = neighbors
                best = [cell]
            } else if neighbors == bestNeighbors {
                best.append(cell)
            }
        }
        best.sort(by: isBefore)
        return best.randomElement(using: &rng)
    }

    private static func chosenShape<R: RandomNumberGenerator>(
        from start: CellIndex,
        free: Set<CellIndex>,
        difficulty: Difficulty,
        maxSize: Int,
        rng: inout R
    ) -> [CellIndex]? {
        let sizes = (2...max(2, maxSize)).filter { difficulty.cageWeight(for: $0) > 0 }
        guard !sizes.isEmpty else { return nil }
        var bag: [Int] = []
        for size in sizes {
            bag.append(contentsOf: Array(repeating: size, count: difficulty.cageWeight(for: size)))
        }
        bag.shuffle(using: &rng)
        var tried = Set<Int>()
        for size in bag where tried.insert(size).inserted {
            if let shape = shape(from: start, count: size, free: free, difficulty: difficulty, rng: &rng) {
                return shape
            }
        }
        for size in sizes.sorted() {
            if let shape = shape(from: start, count: size, free: free, difficulty: difficulty, rng: &rng) {
                return shape
            }
        }
        return nil
    }

    private static func shape<R: RandomNumberGenerator>(
        from start: CellIndex,
        count: Int,
        free: Set<CellIndex>,
        difficulty: Difficulty,
        rng: inout R
    ) -> [CellIndex]? {
        var straight: [[CellIndex]] = []
        if count < 5 || difficulty != .hard {
            for step in orthogonalSteps {
                var run = [start]
                var cursor = start
                var fits = true
                for _ in 1..<count {
                    let next = CellIndex(row: cursor.row + step.0, column: cursor.column + step.1)
                    guard free.contains(next) else {
                        fits = false
                        break
                    }
                    run.append(next)
                    cursor = next
                }
                if fits {
                    straight.append(run)
                }
            }
        }

        let bend = difficulty.bendChance(for: count)
        let wantsBend = bend >= 10 || (bend > 0 && Int.random(in: 0..<10, using: &rng) < bend)
        if wantsBend || (difficulty != .easy && straight.isEmpty && count >= 3) {
            let minTurns = count >= 5 ? 2 : 1
            let bent = bentShapes(from: start, count: count, free: free, minTurns: minTurns, rng: &rng)
            if wantsBend, let choice = bent.randomElement(using: &rng) {
                return choice
            }
            straight.append(contentsOf: bent)
        }
        return straight.randomElement(using: &rng)
    }

    private static func bentShapes<R: RandomNumberGenerator>(
        from start: CellIndex,
        count: Int,
        free: Set<CellIndex>,
        minTurns: Int,
        rng: inout R
    ) -> [[CellIndex]] {
        var found: [[CellIndex]] = []
        func search(path: [CellIndex], used: Set<CellIndex>, turns: Int, lastStep: (Int, Int)?) {
            if found.count == 8 { return }
            if path.count == count {
                if turns >= minTurns {
                    found.append(path)
                }
                return
            }
            guard let end = path.last else { return }
            var steps = orthogonalSteps
            steps.shuffle(using: &rng)
            let turnsStillNeeded = minTurns - turns
            let stepsLeftAfterThis = count - path.count - 1
            let mustTurn = lastStep != nil && turnsStillNeeded > stepsLeftAfterThis
            for step in steps {
                if mustTurn, let lastStep, step == lastStep { continue }
                let next = CellIndex(row: end.row + step.0, column: end.column + step.1)
                guard free.contains(next), !used.contains(next) else { continue }
                var nextUsed = used
                nextUsed.insert(next)
                let nextTurns = lastStep.map { $0 == step ? turns : turns + 1 } ?? turns
                search(path: path + [next], used: nextUsed, turns: nextTurns, lastStep: step)
            }
        }
        search(path: [start], used: [start], turns: 0, lastStep: nil)
        return found
    }

    private static func absorbOrphans<R: RandomNumberGenerator>(
        _ groups: inout [[CellIndex]],
        free: inout Set<CellIndex>,
        difficulty: Difficulty,
        maxSize: Int,
        rng: inout R
    ) {
        var changed = true
        while changed {
            changed = false
            if let pair = adjacentFreePair(in: free, rng: &rng) {
                groups.append(pair)
                free.subtract(pair)
                changed = true
                continue
            }
            for cell in free.sorted(by: isBefore).shuffled(using: &rng) {
                guard let stolen = steal(cell, from: &groups, difficulty: difficulty, maxSize: maxSize) else { continue }
                groups.append([cell, stolen])
                free.remove(cell)
                changed = true
                break
            }
        }
    }

    private static func adjacentFreePair<R: RandomNumberGenerator>(
        in free: Set<CellIndex>,
        rng: inout R
    ) -> [CellIndex]? {
        for cell in free.sorted(by: isBefore).shuffled(using: &rng) {
            for step in orthogonalSteps {
                let next = CellIndex(row: cell.row + step.0, column: cell.column + step.1)
                if free.contains(next) {
                    return [cell, next]
                }
            }
        }
        return nil
    }

    private static func steal(
        _ orphan: CellIndex,
        from groups: inout [[CellIndex]],
        difficulty: Difficulty,
        maxSize: Int
    ) -> CellIndex? {
        for index in groups.indices {
            guard groups[index].count >= 3 else { continue }
            for cell in groups[index] {
                let gap = abs(cell.row - orphan.row) + abs(cell.column - orphan.column)
                guard gap == 1 else { continue }
                let rest = groups[index].filter { $0 != cell }
                guard allowedSnake(rest, difficulty: difficulty, maxSize: maxSize) != nil else { continue }
                groups[index] = rest
                return cell
            }
        }
        return nil
    }

    /// Straight 2s and 3s that cover the board. Bands mix horizontal and vertical runs.
    private static func straightCover<R: RandomNumberGenerator>(
        size: Int,
        rng: inout R
    ) -> [[CellIndex]] {
        var groups: [[CellIndex]] = []
        var row = 0
        for bandHeight in composition(of: size, rng: &rng) {
            if Bool.random(using: &rng) {
                for column in 0..<size {
                    var cursor = row
                    for part in composition(of: bandHeight, rng: &rng) {
                        var cells: [CellIndex] = []
                        for offset in 0..<part {
                            cells.append(CellIndex(row: cursor + offset, column: column))
                        }
                        groups.append(cells)
                        cursor += part
                    }
                }
            } else {
                for line in row..<(row + bandHeight) {
                    var column = 0
                    for part in composition(of: size, rng: &rng) {
                        var cells: [CellIndex] = []
                        for offset in 0..<part {
                            cells.append(CellIndex(row: line, column: column + offset))
                        }
                        groups.append(cells)
                        column += part
                    }
                }
            }
            row += bandHeight
        }
        if Bool.random(using: &rng) {
            groups = transposed(groups)
        }
        return groups
    }

    /// Parallel dominoes with a single perpendicular seam. Odd pair covers look like this.
    private static func isSeamedPairLayout(_ groups: [[CellIndex]], size: Int) -> Bool {
        guard size % 2 == 1 else { return false }
        let occupied = groups.filter { !$0.isEmpty }
        let pairs = occupied.filter { $0.count == 2 }
        let singles = occupied.filter { $0.count == 1 }
        guard singles.count <= 1, pairs.count + singles.count == occupied.count, !pairs.isEmpty else { return false }

        let horizontal = pairs.filter { $0[0].row == $0[1].row }
        let vertical = pairs.filter { $0[0].column == $0[1].column }
        guard horizontal.count + vertical.count == pairs.count else { return false }
        let minorityIsVertical = vertical.count <= horizontal.count
        let minority = minorityIsVertical ? vertical : horizontal
        let majority = minorityIsVertical ? horizontal : vertical
        guard !minority.isEmpty, minority.count * 2 <= size, majority.count > minority.count else { return false }
        if minorityIsVertical {
            return Set(minority.flatMap { $0.map(\.column) }).count == 1
        }
        return Set(minority.flatMap { $0.map(\.row) }).count == 1
    }

    private static func longestCage(in groups: [[CellIndex]]) -> Int {
        groups.map(\.count).max() ?? 0
    }

    /// Joins the odd domino seam into one longer cage so the board is not a striped pair grid.
    private static func breakSeamedPairs(_ groups: [[CellIndex]]) -> [[CellIndex]] {
        var groups = groups.filter { !$0.isEmpty }
        if let singleIndex = groups.firstIndex(where: { $0.count == 1 }) {
            let single = groups[singleIndex]
            if let pairIndex = groups.indices.first(where: { index in
                index != singleIndex && groups[index].count == 2 && sharesEdge(groups[index], single)
            }) {
                groups[pairIndex].append(contentsOf: single)
                groups.remove(at: singleIndex)
                return groups
            }
        }
        let pairIndexes = groups.indices.filter { groups[$0].count == 2 }
        for left in pairIndexes {
            for right in pairIndexes where right > left {
                let leftCells = groups[left]
                let rightCells = groups[right]
                let leftHorizontal = leftCells[0].row == leftCells[1].row
                let rightHorizontal = rightCells[0].row == rightCells[1].row
                guard leftHorizontal != rightHorizontal, sharesEdge(leftCells, rightCells) else { continue }
                groups[left].append(contentsOf: rightCells)
                groups.remove(at: right)
                return groups
            }
        }
        return groups
    }

    /// Pairs, plus one single on an odd board. A grid of pairs cannot cover an odd number of cells.
    private static func pairCover<R: RandomNumberGenerator>(
        size: Int,
        rng: inout R
    ) -> [[CellIndex]] {
        var groups: [[CellIndex]] = []
        let evenWidth = size - (size % 2)
        for row in 0..<size {
            var column = 0
            while column < evenWidth {
                groups.append([
                    CellIndex(row: row, column: column),
                    CellIndex(row: row, column: column + 1)
                ])
                column += 2
            }
        }
        if size % 2 == 1 {
            var row = 0
            while row + 1 < size {
                groups.append([
                    CellIndex(row: row, column: size - 1),
                    CellIndex(row: row + 1, column: size - 1)
                ])
                row += 2
            }
            groups.append([CellIndex(row: size - 1, column: size - 1)])
        }
        if Bool.random(using: &rng) {
            groups = transposed(groups)
        }
        if Bool.random(using: &rng) {
            groups = groups.map { cage in
                cage.map { CellIndex(row: size - 1 - $0.row, column: $0.column) }
            }
        }
        if Bool.random(using: &rng) {
            groups = groups.map { cage in
                cage.map { CellIndex(row: $0.row, column: size - 1 - $0.column) }
            }
        }
        return groups
    }

    /// Every length except 1 can be split into 2s and 3s. Never leave a single cell.
    private static func composition<R: RandomNumberGenerator>(
        of length: Int,
        rng: inout R
    ) -> [Int] {
        var parts: [Int] = []
        var left = length
        while left > 0 {
            let canUseTwo = left >= 2 && left != 3
            let canUseThree = left >= 3 && left != 4
            let part: Int
            if canUseTwo && canUseThree {
                part = Bool.random(using: &rng) ? 2 : 3
            } else if canUseThree {
                part = 3
            } else if canUseTwo {
                part = 2
            } else {
                part = left
            }
            parts.append(part)
            left -= part
        }
        return parts
    }

    /// Merges pairs into the larger cages, then bends some of the straight triples.
    private static func reshape<R: RandomNumberGenerator>(
        _ groups: [[CellIndex]],
        difficulty: Difficulty,
        maxSize: Int,
        rng: inout R
    ) -> [[CellIndex]] {
        var groups = groups
        let cellCount = groups.reduce(0) { $0 + $1.count }
        let profile = targetProfile(cellCount: cellCount, difficulty: difficulty, maxSize: maxSize)
        if maxSize >= 5 {
            groups = mergeMatches(
                groups,
                leftSize: 2,
                rightSize: 3,
                difficulty: difficulty,
                maxSize: maxSize,
                wanted: profile.cages[5],
                preferBent: profile.bends[5],
                rng: &rng
            )
        }
        groups = bendTriples(groups, wanted: profile.bends[3], rng: &rng)
        if maxSize >= 5 {
            let remaining = profile.cages[5] - groups.filter { $0.count == 5 }.count
            groups = mergeMatches(
                groups,
                leftSize: 2,
                rightSize: 3,
                difficulty: difficulty,
                maxSize: maxSize,
                wanted: remaining,
                preferBent: remaining,
                rng: &rng
            )
        }
        if maxSize >= 4 {
            groups = mergeMatches(
                groups,
                leftSize: 2,
                rightSize: 2,
                difficulty: difficulty,
                maxSize: maxSize,
                wanted: profile.cages[4],
                preferBent: profile.bends[4],
                rng: &rng
            )
        }
        return groups
    }

    private static func targetProfile(
        cellCount: Int,
        difficulty: Difficulty,
        maxSize: Int
    ) -> (cages: [Int], bends: [Int]) {
        var massBySize = Array(repeating: 0, count: maxSize + 1)
        var mass = 0
        for size in 2...maxSize {
            let weight = size * difficulty.cageWeight(for: size)
            massBySize[size] = weight
            mass += weight
        }
        var cages = Array(repeating: 0, count: maxSize + 1)
        var bends = Array(repeating: 0, count: maxSize + 1)
        guard mass > 0 else { return (cages, bends) }
        for size in 2...maxSize {
            let cells = Double(cellCount * massBySize[size]) / Double(mass)
            let desired = Int((cells / Double(size)).rounded())
            cages[size] = desired
            let bendTarget = Double(desired * difficulty.bendChance(for: size)) / 10
            bends[size] = Int(bendTarget.rounded())
        }
        return (cages, bends)
    }

    /// Joins adjacent cages of two sizes. Bent results are taken first, up to `preferBent`.
    private static func mergeMatches<R: RandomNumberGenerator>(
        _ groups: [[CellIndex]],
        leftSize: Int,
        rightSize: Int,
        difficulty: Difficulty,
        maxSize: Int,
        wanted: Int,
        preferBent: Int,
        rng: inout R
    ) -> [[CellIndex]] {
        guard wanted > 0 else { return groups }
        var pairs: [(Int, Int)] = []
        for left in groups.indices {
            for right in (left + 1)..<groups.count {
                let leftCount = groups[left].count
                let rightCount = groups[right].count
                let sizesMatch = (leftCount == leftSize && rightCount == rightSize)
                    || (leftCount == rightSize && rightCount == leftSize)
                guard sizesMatch, sharesEdge(groups[left], groups[right]) else { continue }
                pairs.append((left, right))
            }
        }
        pairs.shuffle(using: &rng)

        var bentPairs: [(Int, Int)] = []
        var straightPairs: [(Int, Int)] = []
        for pair in pairs {
            let union = groups[pair.0] + groups[pair.1]
            guard allowedSnake(union, difficulty: difficulty, maxSize: maxSize) != nil else { continue }
            if isStraightRun(union) {
                straightPairs.append(pair)
            } else {
                bentPairs.append(pair)
            }
        }

        var chosen: [(Int, Int)] = []
        var used = Set<Int>()
        func take(from pool: [(Int, Int)], limit: Int) {
            var taken = 0
            for pair in pool {
                if chosen.count >= wanted || taken >= limit { return }
                if used.contains(pair.0) || used.contains(pair.1) { continue }
                used.insert(pair.0)
                used.insert(pair.1)
                chosen.append(pair)
                taken += 1
            }
        }
        take(from: bentPairs, limit: min(preferBent, wanted))
        take(from: straightPairs, limit: wanted)
        take(from: bentPairs, limit: wanted)

        var removed = Set<Int>()
        var added: [[CellIndex]] = []
        for pair in chosen {
            let union = groups[pair.0] + groups[pair.1]
            guard let snake = allowedSnake(union, difficulty: difficulty, maxSize: maxSize) else { continue }
            removed.insert(pair.0)
            removed.insert(pair.1)
            added.append(snake)
        }
        return groups.enumerated().compactMap { removed.contains($0.offset) ? nil : $0.element } + added
    }

    /// Turns a filled 2×3 rectangle of two straight triples into a pair of L cages.
    private static func bendTriples<R: RandomNumberGenerator>(
        _ groups: [[CellIndex]],
        wanted: Int,
        rng: inout R
    ) -> [[CellIndex]] {
        guard wanted > 0 else { return groups }
        var candidates: [(Int, Int, [[CellIndex]])] = []
        for left in groups.indices {
            guard groups[left].count == 3, isStraightRun(groups[left]) else { continue }
            for right in (left + 1)..<groups.count {
                guard groups[right].count == 3, isStraightRun(groups[right]), sharesEdge(groups[left], groups[right]) else { continue }
                let splits = elbowSplits(groups[left] + groups[right])
                guard let pieces = splits.randomElement(using: &rng) else { continue }
                candidates.append((left, right, pieces))
            }
        }
        candidates.shuffle(using: &rng)

        let flips = (wanted + 1) / 2
        var chosen: [(Int, Int, [[CellIndex]])] = []
        var used = Set<Int>()
        for candidate in candidates {
            if chosen.count >= flips { break }
            if used.contains(candidate.0) || used.contains(candidate.1) { continue }
            used.insert(candidate.0)
            used.insert(candidate.1)
            chosen.append(candidate)
        }

        var removed = Set<Int>()
        var added: [[CellIndex]] = []
        for candidate in chosen {
            removed.insert(candidate.0)
            removed.insert(candidate.1)
            added.append(contentsOf: candidate.2)
        }
        return groups.enumerated().compactMap { removed.contains($0.offset) ? nil : $0.element } + added
    }

    private static func elbowSplits(_ cells: [CellIndex]) -> [[[CellIndex]]] {
        guard cells.count == 6 else { return [] }
        let rowList = Set(cells.map(\.row)).sorted()
        let columnList = Set(cells.map(\.column)).sorted()
        guard isContiguous(rowList), isContiguous(columnList) else { return [] }
        guard cells.count == rowList.count * columnList.count else { return [] }

        if rowList.count == 2, columnList.count == 3 {
            let top = rowList[0]
            let bottom = rowList[1]
            let start = columnList[0]
            let middle = columnList[1]
            let end = columnList[2]
            return [
                [
                    [CellIndex(row: top, column: start), CellIndex(row: top, column: middle), CellIndex(row: bottom, column: start)],
                    [CellIndex(row: top, column: end), CellIndex(row: bottom, column: middle), CellIndex(row: bottom, column: end)]
                ],
                [
                    [CellIndex(row: top, column: start), CellIndex(row: bottom, column: start), CellIndex(row: bottom, column: middle)],
                    [CellIndex(row: top, column: middle), CellIndex(row: top, column: end), CellIndex(row: bottom, column: end)]
                ]
            ]
        }
        if rowList.count == 3, columnList.count == 2 {
            let start = rowList[0]
            let middle = rowList[1]
            let end = rowList[2]
            let left = columnList[0]
            let right = columnList[1]
            return [
                [
                    [CellIndex(row: start, column: left), CellIndex(row: middle, column: left), CellIndex(row: start, column: right)],
                    [CellIndex(row: end, column: left), CellIndex(row: middle, column: right), CellIndex(row: end, column: right)]
                ],
                [
                    [CellIndex(row: start, column: left), CellIndex(row: start, column: right), CellIndex(row: middle, column: right)],
                    [CellIndex(row: middle, column: left), CellIndex(row: end, column: left), CellIndex(row: end, column: right)]
                ]
            ]
        }
        return []
    }

    /// A cage is a snake. Easy stays straight. A hard cage of 5 changes direction at least twice.
    private static func allowedSnake(
        _ cells: [CellIndex],
        difficulty: Difficulty,
        maxSize: Int
    ) -> [CellIndex]? {
        let count = cells.count
        guard (2...maxSize).contains(count), difficulty.cageWeight(for: count) > 0 else { return nil }
        if isStraightRun(cells) {
            if difficulty == .hard, count >= 5 { return nil }
            return cells
        }
        guard difficulty != .easy, isConnected(cells) else { return nil }
        let minTurns = count >= 5 ? 2 : 1
        guard hasSnake(cells, minTurns: minTurns) else { return nil }
        return cells
    }

    private static func sharesEdge(_ left: [CellIndex], _ right: [CellIndex]) -> Bool {
        let rightSet = Set(right)
        for cell in left {
            for step in orthogonalSteps {
                let next = CellIndex(row: cell.row + step.0, column: cell.column + step.1)
                if rightSet.contains(next) {
                    return true
                }
            }
        }
        return false
    }

    private static func isConnected(_ cells: [CellIndex]) -> Bool {
        guard let start = cells.first else { return false }
        let remaining = Set(cells)
        var seen: Set<CellIndex> = [start]
        var stack = [start]
        while let cell = stack.popLast() {
            for step in orthogonalSteps {
                let next = CellIndex(row: cell.row + step.0, column: cell.column + step.1)
                if remaining.contains(next), seen.insert(next).inserted {
                    stack.append(next)
                }
            }
        }
        return seen.count == cells.count
    }

    private static func hasSnake(_ cells: [CellIndex], minTurns: Int) -> Bool {
        let count = cells.count
        var adjacent = Array(repeating: [Int](), count: count)
        for left in 0..<count {
            for right in (left + 1)..<count {
                let rowGap = abs(cells[left].row - cells[right].row)
                let columnGap = abs(cells[left].column - cells[right].column)
                guard rowGap + columnGap == 1 else { continue }
                adjacent[left].append(right)
                adjacent[right].append(left)
            }
        }

        func walk(from start: Int) -> Bool {
            var path = [start]
            var used = 1 << start
            func search() -> Bool {
                if path.count == count {
                    return turnCount(path.map { cells[$0] }) >= minTurns
                }
                let turns = path.count < 3 ? 0 : turnCount(path.map { cells[$0] })
                if turns + (count - path.count) < minTurns {
                    return false
                }
                let end = path[path.count - 1]
                for next in adjacent[end] where used & (1 << next) == 0 {
                    used |= 1 << next
                    path.append(next)
                    if search() { return true }
                    path.removeLast()
                    used &= ~(1 << next)
                }
                return false
            }
            return search()
        }

        for start in 0..<count where walk(from: start) {
            return true
        }
        return false
    }

    private static func turnCount(_ path: [CellIndex]) -> Int {
        guard path.count >= 3 else { return 0 }
        var turns = 0
        for index in 2..<path.count {
            let previousRow = path[index - 1].row - path[index - 2].row
            let previousColumn = path[index - 1].column - path[index - 2].column
            let row = path[index].row - path[index - 1].row
            let column = path[index].column - path[index - 1].column
            if previousRow != row || previousColumn != column {
                turns += 1
            }
        }
        return turns
    }

    private static func transposed(_ groups: [[CellIndex]]) -> [[CellIndex]] {
        groups.map { cage in
            cage.map { CellIndex(row: $0.column, column: $0.row) }
        }
    }

    private static func isStraightRun(_ cells: [CellIndex]) -> Bool {
        guard let first = cells.first else { return false }
        if cells.allSatisfy({ $0.row == first.row }) {
            return isContiguous(cells.map(\.column))
        }
        if cells.allSatisfy({ $0.column == first.column }) {
            return isContiguous(cells.map(\.row))
        }
        return false
    }

    private static func isContiguous(_ values: [Int]) -> Bool {
        let unique = Set(values)
        guard unique.count == values.count, let low = unique.min(), let high = unique.max() else { return false }
        return high - low + 1 == unique.count
    }

    private static func makeCages<R: RandomNumberGenerator>(
        startingID: Int,
        cells: [CellIndex],
        solution: [[Int]],
        difficulty: Difficulty,
        rules: OperatorRules,
        rng: inout R
    ) -> [Cage]? {
        let values = cells.map { solution[$0.row][$0.column] }
        if values.count == 1 {
            return [Cage(id: startingID, cells: cells, operation: nil, target: values[0])]
        }

        var options: [(CageOperation, Int)] = []
        let allowed = rules.operations(forCellCount: values.count)
        if allowed.contains(.add) {
            options.append((.add, values.reduce(0, +)))
        }
        if allowed.contains(.multiply) {
            options.append((.multiply, values.reduce(1, *)))
        }
        if values.count == 2 {
            if allowed.contains(.subtract) {
                options.append((.subtract, abs(values[0] - values[1])))
            }
            let high = max(values[0], values[1])
            let low = min(values[0], values[1])
            if allowed.contains(.divide), low > 0, high % low == 0 {
                options.append((.divide, high / low))
            }
        }

        guard let fallback = options.first else { return nil }

        var weighted: [(CageOperation, Int)] = []
        for option in options {
            let copies = max(weight(option.0, difficulty: difficulty, cellCount: values.count), 1)
            weighted.append(contentsOf: Array(repeating: option, count: copies))
        }
        let chosen = weighted.randomElement(using: &rng) ?? fallback
        return [Cage(id: startingID, cells: cells, operation: chosen.0, target: chosen.1)]
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

    /// A board of real cages when the search never proved a unique puzzle. An all-single board would fill itself in.
    private static func playableCover<R: RandomNumberGenerator>(
        size: Int,
        difficulty: Difficulty,
        rules: OperatorRules,
        rng: inout R
    ) -> Puzzle {
        let pairOnly = rules.operations(forCellCount: 3).isEmpty
        let maxSize = pairOnly ? 2 : max(2, difficulty.maxCageSize)
        for _ in 0..<48 {
            let solution = latinSquare(size: size, rng: &rng)
            guard let built = cages(
                from: solution,
                maxSize: maxSize,
                difficulty: difficulty,
                rules: rules,
                rng: &rng
            ) else { continue }
            let puzzle = Puzzle(size: size, cages: built, solution: solution, rules: rules)
            if KenKenRules.solutionIsValid(puzzle) {
                return puzzle
            }
        }
        return greedyPairs(size: size, rules: rules, rng: &rng)
    }

    /// Pairs each cell with a neighbor that can host an enabled operation.
    private static func greedyPairs<R: RandomNumberGenerator>(
        size: Int,
        rules: OperatorRules,
        rng: inout R
    ) -> Puzzle {
        var best: Puzzle?
        var fewestSingles = Int.max
        for _ in 0..<12 {
            let puzzle = greedyBoard(size: size, rules: rules, rng: &rng)
            let singles = puzzle.cages.filter { $0.cells.count == 1 }.count
            if singles < fewestSingles {
                best = puzzle
                fewestSingles = singles
            }
            if singles <= size % 2 {
                break
            }
        }
        return best ?? greedyBoard(size: size, rules: rules, rng: &rng)
    }

    private static func greedyBoard<R: RandomNumberGenerator>(
        size: Int,
        rules: OperatorRules,
        rng: inout R
    ) -> Puzzle {
        let solution = latinSquare(size: size, rng: &rng)
        let allowLarger = !rules.operations(forCellCount: 3).isEmpty
        var groups: [[CellIndex]]
        if allowLarger {
            var tiled = straightCover(size: size, rng: &rng)
            tiled = reshape(tiled, difficulty: .medium, maxSize: 4, rng: &rng)
            if longestCage(in: tiled) < 3 || isSeamedPairLayout(tiled, size: size) {
                tiled = breakSeamedPairs(tiled)
            }
            groups = tiled
        } else {
            var free = Set((0..<size).flatMap { row in
                (0..<size).map { CellIndex(row: row, column: $0) }
            })
            groups = []
            for cell in free.sorted(by: isBefore) {
                guard free.contains(cell) else { continue }
                free.remove(cell)
                let partner = orthogonalSteps.compactMap { step -> CellIndex? in
                    let next = CellIndex(row: cell.row + step.0, column: cell.column + step.1)
                    guard free.contains(next), operationFits([cell, next], solution: solution, rules: rules) else { return nil }
                    return next
                }.min(by: isBefore)
                if let partner {
                    free.remove(partner)
                    groups.append([cell, partner])
                } else {
                    groups.append([cell])
                }
            }
        }
        var built: [Cage] = []
        for cells in groups {
            if let made = makeCages(
                startingID: built.count,
                cells: cells,
                solution: solution,
                difficulty: .easy,
                rules: rules,
                rng: &rng
            ) {
                built.append(contentsOf: made)
            } else {
                for cell in cells {
                    built.append(
                        Cage(id: built.count, cells: [cell], operation: nil, target: solution[cell.row][cell.column])
                    )
                }
            }
        }
        return Puzzle(size: size, cages: built, solution: solution, rules: rules)
    }

    private static func operationFits(
        _ cells: [CellIndex],
        solution: [[Int]],
        rules: OperatorRules
    ) -> Bool {
        let values = cells.map { solution[$0.row][$0.column] }
        let allowed = rules.operations(forCellCount: values.count)
        if allowed.contains(.add) || allowed.contains(.multiply) || allowed.contains(.subtract) {
            return true
        }
        guard allowed.contains(.divide), values.count == 2 else { return false }
        let low = min(values[0], values[1])
        let high = max(values[0], values[1])
        return low > 0 && high % low == 0
    }
}

nonisolated enum KenKenSolver {
    struct Outcome: Equatable, Sendable {
        var count: Int
        var reachedLimit: Bool
        var solutions: [[[Int]]]
    }

    static func countSolutions(of puzzle: Puzzle, limit: Int = 2, nodeLimit: Int = 12_000) -> Outcome {
        var search = Search(puzzle: puzzle, limit: limit, nodeLimit: nodeLimit)
        search.explore()
        return Outcome(count: search.count, reachedLimit: search.reachedLimit, solutions: search.solutions)
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
        var solutions: [[[Int]]] = []

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
                if solutions.count < limit {
                    solutions.append(grid)
                }
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
                let fits = allows(
                    value,
                    operation: cage.operation,
                    target: cage.target,
                    filled: filled,
                    emptyOthers: emptyOthers
                )
                if fits {
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
