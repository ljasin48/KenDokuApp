//
//  TutorialView.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/12/26.
//

import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var entries = TutorialPuzzle.puzzle.startingEntries()
    @State private var selection: CellIndex? = TutorialPuzzle.steps[0].focus
    @State private var stepIndex = 0
    @State private var notice: String?

    private var step: TutorialStep {
        TutorialPuzzle.steps[stepIndex]
    }

    var body: some View {
        VStack(spacing: 16) {
            instruction
            MathdokuBoard(
                puzzle: TutorialPuzzle.puzzle,
                entries: entries,
                notes: TutorialPuzzle.notes,
                selection: selection,
                analysis: .empty,
                highlight: .off,
                onSelect: { _ in selection = step.focus }
            )
            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
            .frame(maxWidth: 420)

            controls
        }
        .padding(20)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { MathdokuBackground() }
        .navigationTitle("Tutorial")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: { dismiss() })
            }
        }
        .onChange(of: stepIndex) {
            selection = step.focus
            notice = nil
        }
        #if os(iOS) || os(macOS) || os(visionOS)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(characters: .decimalDigits) { press in
            guard let number = press.characters.first?.wholeNumberValue,
                  (1...3).contains(number) else { return .ignored }
            enter(number)
            return .handled
        }
        #endif
    }

    private var instruction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step \(stepIndex + 1) of \(TutorialPuzzle.steps.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(step.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            if let notice {
                Text(notice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if stepIndex > 0 {
                Button(action: goBack) {
                    Text("Previous")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(width: step.place == nil ? nil : 112, height: 52)
                }
                .buttonStyle(MathdokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 12))
                .buttonSizing(.flexible)
            }

            if step.place == nil {
                advanceButton
            } else {
                numberPad
            }
        }
    }

    private var advanceButton: some View {
        Button {
            if step.isLast {
                dismiss()
            } else {
                stepIndex += 1
            }
        } label: {
            Text(step.isLast ? "Done" : "Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(
            MathdokuGlassButtonStyle(
                glass: .regular.tint(theme.accent).interactive(),
                cornerRadius: 12
            )
        )
        .buttonSizing(.flexible)
    }

    private var numberPad: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { number in
                Button {
                    enter(number)
                } label: {
                    Text("\(number)")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(MathdokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 12))
                .buttonSizing(.flexible)
            }
        }
    }

    private func enter(_ number: Int) {
        guard let place = step.place else { return }
        guard number == place.value else {
            notice = step.retry
            return
        }
        entries[place.row][place.column] = number
        notice = nil
        stepIndex += 1
    }

    private func goBack() {
        guard stepIndex > 0 else { return }
        if let place = TutorialPuzzle.steps[stepIndex - 1].place {
            entries[place.row][place.column] = nil
        }
        stepIndex -= 1
    }
}

private struct TutorialPlacement {
    var row: Int
    var column: Int
    var value: Int
}

private struct TutorialStep {
    var text: String
    var focus: CellIndex?
    var place: TutorialPlacement?
    var retry: String?
    var isLast = false
}

private enum TutorialPuzzle {
    /// Solution, for the steps below:
    /// 2 1 3
    /// 3 2 1
    /// 1 3 2
    static let puzzle: Puzzle = {
        let cages = [
            Cage(id: 0, cells: [CellIndex(row: 0, column: 0)], operation: nil, target: 2),
            Cage(
                id: 1,
                cells: [CellIndex(row: 0, column: 1), CellIndex(row: 0, column: 2)],
                operation: .add,
                target: 4
            ),
            Cage(
                id: 2,
                cells: [CellIndex(row: 1, column: 0), CellIndex(row: 2, column: 0)],
                operation: .subtract,
                target: 2
            ),
            Cage(id: 3, cells: [CellIndex(row: 2, column: 1)], operation: nil, target: 3),
            Cage(
                id: 4,
                cells: [
                    CellIndex(row: 1, column: 1),
                    CellIndex(row: 1, column: 2),
                    CellIndex(row: 2, column: 2)
                ],
                operation: .multiply,
                target: 4
            )
        ]
        let solution = [
            [2, 1, 3],
            [3, 2, 1],
            [1, 3, 2]
        ]
        return Puzzle(size: 3, cages: cages, solution: solution)
    }()

    static let notes: [[Set<Int>]] = Array(
        repeating: Array(repeating: [], count: 3),
        count: 3
    )

    static let steps: [TutorialStep] = [
        TutorialStep(
            text: "Each row and each column uses 1, 2, and 3 exactly once. Cells are organized into groups containing a target number and operation.",
            focus: nil
        ),
        TutorialStep(
            text: "The left group is 2\u{2212}. Its two cells subtract to 2, in either order. The column already has a 2, so the open cells are 1 and 3. The bottom row already has a 3, so this cell is 1. Tap 1.",
            focus: CellIndex(row: 2, column: 0),
            place: TutorialPlacement(row: 2, column: 0, value: 1),
            retry: "The bottom row already has a 3, so this cell is 1."
        ),
        TutorialStep(
            text: "3 \u{2212} 1 = 2, so the other cell in that group is 3. Tap 3.",
            focus: CellIndex(row: 1, column: 0),
            place: TutorialPlacement(row: 1, column: 0, value: 3),
            retry: "This cell is 3."
        ),
        TutorialStep(
            text: "The top group is 4+. Its cells add to 4. The row already has a 2, so the pair is 1 and 3. This column already has a 3, so this cell is 1. Tap 1.",
            focus: CellIndex(row: 0, column: 1),
            place: TutorialPlacement(row: 0, column: 1, value: 1),
            retry: "This column already has a 3, so this cell is 1."
        ),
        TutorialStep(
            text: "The last cell in the top row is 3, and 1 + 3 = 4. Tap 3.",
            focus: CellIndex(row: 0, column: 2),
            place: TutorialPlacement(row: 0, column: 2, value: 3),
            retry: "This cell is 3."
        ),
        TutorialStep(
            text: "The remaining group is 4\u{00D7}. Its cells multiply to 4. This column already has 1 and 3, so this cell is 2. Tap 2.",
            focus: CellIndex(row: 1, column: 1),
            place: TutorialPlacement(row: 1, column: 1, value: 2),
            retry: "This column already has 1 and 3, so this cell is 2."
        ),
        TutorialStep(
            text: "This row already has 3 and 2, so this cell is 1. Tap 1.",
            focus: CellIndex(row: 1, column: 2),
            place: TutorialPlacement(row: 1, column: 2, value: 1),
            retry: "This cell is 1."
        ),
        TutorialStep(
            text: "One cell is left. Its column already has 3 and 1, so it is 2. Then 2 \u{00D7} 1 \u{00D7} 2 = 4. Tap 2.",
            focus: CellIndex(row: 2, column: 2),
            place: TutorialPlacement(row: 2, column: 2, value: 2),
            retry: "This cell is 2."
        ),
        TutorialStep(
            text: "The puzzle is finished. Every row and column has 1, 2, and 3 once, and every cell group hits its target. Division works like subtraction: the two cells can go in either order. A normal game also has Undo, Erase, Hint, Combos, and Notes.",
            focus: nil,
            isLast: true
        )
    ]
}

#Preview {
    NavigationStack {
        TutorialView()
            .mathdokuScreen()
    }
    .mathdokuScreen()
}
