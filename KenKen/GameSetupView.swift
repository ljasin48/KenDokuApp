//
//  GameSetupView.swift
//  KenKen
//
//  Created by Logan Jasin on 11/7/26.
//

import SwiftUI

enum GameSettings {
    static let size = "kendoku.size"
    static let difficulty = "kendoku.difficulty"
    static let highlightMistakes = "kendoku.highlightMistakes"
    static let allowAdd = "kendoku.allowAdd"
    static let allowSubtract = "kendoku.allowSubtract"
    static let allowMultiply = "kendoku.allowMultiply"
    static let allowDivide = "kendoku.allowDivide"
    static let hideOperators = "kendoku.hideOperators"
    static let theme = "kendoku.theme"
}

struct GameLaunch: Hashable {
    var size: Int
    var difficulty: Difficulty
    var seed: UInt64?
    var isDaily: Bool
    var id: UInt64

    static let sizes = [3, 4, 5, 6, 7, 8, 9]

    static func daily(on date: Date = .now) -> GameLaunch {
        let seed = DayStamp.seed(from: date)
        return GameLaunch(size: 6, difficulty: .hard, seed: seed, isDaily: true, id: seed)
    }

    static func random(size: Int, difficulty: Difficulty) -> GameLaunch {
        GameLaunch(
            size: size,
            difficulty: difficulty,
            seed: nil,
            isDaily: false,
            id: UInt64.random(in: 1...UInt64.max)
        )
    }
}

struct OperatorRulesEditor: View {
    @AppStorage(GameSettings.allowAdd) private var allowAdd = true
    @AppStorage(GameSettings.allowSubtract) private var allowSubtract = true
    @AppStorage(GameSettings.allowMultiply) private var allowMultiply = true
    @AppStorage(GameSettings.allowDivide) private var allowDivide = true
    @AppStorage(GameSettings.hideOperators) private var hideOperators = false

    private var rules: OperatorRules {
        OperatorRules(
            add: allowAdd,
            subtract: allowSubtract,
            multiply: allowMultiply,
            divide: allowDivide,
            hidesOperators: hideOperators
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Operators")
                .font(.headline)
            Text("New games use the operations you leave on. At least one stays selected, and division cannot be the only one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(CageOperation.allCases) { operation in
                    operatorButton(operation)
                }
            }

            Toggle(isOn: $hideOperators) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No-op mode")
                    Text("Hide the operation symbol. The puzzle itself stays the same.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))

            Text("The daily puzzle always shows all four operations.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            let fixed = rules.normalized
            allowAdd = fixed.add
            allowSubtract = fixed.subtract
            allowMultiply = fixed.multiply
            allowDivide = fixed.divide
        }
    }

    private func operatorButton(_ operation: CageOperation) -> some View {
        let isOn = rules.allows(operation)
        let glass: Glass = isOn ? .regular.tint(Color.accentColor).interactive() : .regular.interactive()
        return operatorControl(operation, isOn: isOn)
            .buttonStyle(KenDokuGlassButtonStyle(glass: glass, cornerRadius: 12))
    }

    private func operatorControl(_ operation: CageOperation, isOn: Bool) -> some View {
        Button {
            toggle(operation)
        } label: {
            Text(operation.symbol)
                .font(.title.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .accessibilityLabel(operation.name)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func toggle(_ operation: CageOperation) {
        var next = rules
        next.set(operation, enabled: !next.allows(operation))
        guard !next.enabledOperations.isEmpty, !next.isDivideOnly else { return }
        allowAdd = next.add
        allowSubtract = next.subtract
        allowMultiply = next.multiply
        allowDivide = next.divide
    }
}

#Preview {
    OperatorRulesEditor()
        .padding()
}
