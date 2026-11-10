//
//  GameDeck.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/9/26.
//

import Foundation
import Observation

/// One unstarted puzzle for the saved size, difficulty, and operators.
/// The landing page stays put. A finished board is handed over when a new game starts, then the next one begins.
/// No-op only changes the clue label, so it does not replace the deck. The daily board has its own seed and is not stored here.
@Observable
final class GameDeck {
    struct Spec: Equatable {
        var size: Int
        var difficulty: Difficulty
        var add: Bool
        var subtract: Bool
        var multiply: Bool
        var divide: Bool

        var rules: OperatorRules {
            OperatorRules(
                add: add,
                subtract: subtract,
                multiply: multiply,
                divide: divide,
                hidesOperators: false
            )
        }

        init(size: Int, difficulty: Difficulty, rules: OperatorRules) {
            let rules = rules.normalized
            self.size = size
            self.difficulty = difficulty
            add = rules.add
            subtract = rules.subtract
            multiply = rules.multiply
            divide = rules.divide
        }

        static func stored(defaults: UserDefaults = .standard) -> Spec {
            let storedSize = defaults.object(forKey: GameSettings.size) as? Int ?? 4
            let size = GameLaunch.sizes.contains(storedSize) ? storedSize : 4
            let difficulty = Difficulty(rawValue: defaults.string(forKey: GameSettings.difficulty) ?? "") ?? .medium
            let rules = OperatorRules(
                add: defaults.object(forKey: GameSettings.allowAdd) as? Bool ?? true,
                subtract: defaults.object(forKey: GameSettings.allowSubtract) as? Bool ?? true,
                multiply: defaults.object(forKey: GameSettings.allowMultiply) as? Bool ?? true,
                divide: defaults.object(forKey: GameSettings.allowDivide) as? Bool ?? true,
                hidesOperators: false
            )
            return Spec(size: size, difficulty: difficulty, rules: rules)
        }
    }

    private static let settleNanoseconds: UInt64 = 500_000_000

    private var spec: Spec?
    private var puzzle: Puzzle?
    private var ticket = 0
    private var task: Task<Void, Never>?
    private var debounce: Task<Void, Never>?

    init(autostart: Bool = true) {
        if autostart {
            start(Spec.stored(), priority: .utility)
        }
    }

    /// Builds a replacement after board settings stay still. A matching board or an in-flight build is left alone.
    func prepare(_ spec: Spec, debounced: Bool) {
        debounce?.cancel()
        if retains(spec) {
            debounce = nil
            return
        }
        guard debounced else {
            debounce = nil
            start(spec, priority: .utility)
            return
        }
        debounce = Task {
            try? await Task.sleep(nanoseconds: Self.settleNanoseconds)
            guard !Task.isCancelled else { return }
            start(spec, priority: .utility)
        }
    }

    /// The ready board for this setup, or nil while it is still building. Taking it starts the one after.
    func takeIfReady(_ spec: Spec) -> Puzzle? {
        guard let puzzle, self.spec == spec else { return nil }
        self.puzzle = nil
        start(spec, priority: .utility)
        return puzzle
    }

    /// Waits for the board that matches this setup. A settings change that lands first is not returned.
    func puzzle(for spec: Spec) async -> Puzzle {
        if let ready = takeIfReady(spec) { return ready }
        debounce?.cancel()
        debounce = nil
        if !retains(spec) {
            start(spec, priority: .userInitiated)
        }
        let current = ticket
        while puzzle == nil && ticket == current {
            guard let task else { break }
            await task.value
        }
        if let ready = takeIfReady(spec) { return ready }
        let size = spec.size
        let difficulty = spec.difficulty
        let rules = spec.rules
        return await Task.detached(priority: .userInitiated) {
            MathdokuGenerator.generate(size: size, difficulty: difficulty, seed: nil, rules: rules)
        }.value
    }

    static var preview: GameDeck {
        GameDeck(autostart: false)
    }

    private func retains(_ spec: Spec) -> Bool {
        self.spec == spec && (puzzle != nil || task != nil)
    }

    private func start(_ spec: Spec, priority: TaskPriority) {
        if retains(spec) { return }
        self.spec = spec
        puzzle = nil
        ticket += 1
        let current = ticket
        let size = spec.size
        let difficulty = spec.difficulty
        let rules = spec.rules
        task = Task {
            let generated = await Task.detached(priority: priority) {
                MathdokuGenerator.generate(size: size, difficulty: difficulty, seed: nil, rules: rules)
            }.value
            guard current == self.ticket else { return }
            self.puzzle = generated
            self.task = nil
        }
    }
}
