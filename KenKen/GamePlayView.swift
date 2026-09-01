//
//  GamePlayView.swift
//  KenKen
//
//  Created by Logan Jasin on 11/7/26.
//

import SwiftUI

struct GamePlayView: View {
    let launch: GameLaunch

    @Environment(PlayerStats.self) private var stats
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GameSettings.highlightMistakes) private var highlightMistakes = true

    @State private var loadID = 0
    @State private var installedID: Int?
    @State private var isLoading = true
    @State private var puzzle: Puzzle?
    @State private var entries: [[Int?]] = []
    @State private var notes: [[Set<Int>]] = []
    @State private var selection: CellIndex?
    @State private var undoStack: [Move] = []
    @State private var notesMode = false
    @State private var didFinish = false
    @State private var usedHint = false
    @State private var hideWinCard = false
    @State private var startedAt: Date?
    @State private var frozenSeconds = 0
    @State private var confirmClear = false
    @State private var confirmNew = false

    var body: some View {
        ZStack {
            KenDokuBackground()
            if isLoading || puzzle == nil {
                ProgressView("Building a \(launch.size)\u{00D7}\(launch.size)")
                    .tint(.white)
            } else if let puzzle {
                playfield(puzzle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(launch.isDaily ? "Daily Puzzle" : "\(launch.size)\u{00D7}\(launch.size)")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
        .preferredColorScheme(.dark)
        .task(id: loadID) {
            await loadPuzzle()
        }
        .confirmationDialog("Clear this board?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear Board", role: .destructive, action: clearBoard)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Numbers and notes on this puzzle will be erased.")
        }
        .confirmationDialog("Start a new puzzle?", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("New Puzzle", role: .destructive) { loadID += 1 }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This board will be replaced.")
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: didFinish)
        #endif
        #if os(iOS) || os(macOS) || os(visionOS)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(characters: .decimalDigits) { press in
            guard let number = press.characters.first?.wholeNumberValue,
                  (1...launch.size).contains(number) else { return .ignored }
            pressNumber(number)
            return .handled
        }
        .onKeyPress(.delete) {
            erase()
            return .handled
        }
        .onKeyPress(.leftArrow) { nudge(row: 0, column: -1); return .handled }
        .onKeyPress(.rightArrow) { nudge(row: 0, column: 1); return .handled }
        .onKeyPress(.upArrow) { nudge(row: -1, column: 0); return .handled }
        .onKeyPress(.downArrow) { nudge(row: 1, column: 0); return .handled }
        #endif
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button("Clear", systemImage: "arrow.counterclockwise", action: requestClear)
                .disabled(puzzle == nil)
            if !launch.isDaily {
                Button("New Puzzle", systemImage: "plus", action: requestNewPuzzle)
                    .disabled(isLoading)
            }
        }
    }

    private func playfield(_ puzzle: Puzzle) -> some View {
        VStack(spacing: 14) {
            statusBar
            KenKenBoard(
                puzzle: puzzle,
                entries: entries,
                notes: notes,
                selection: selection,
                analysis: analysis(for: puzzle),
                showMistakes: highlightMistakes,
                onSelect: { selection = $0 }
            )
            .frame(maxWidth: 640)
            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)

            numberPad(size: puzzle.size)
            toolRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if didFinish && !hideWinCard {
                winCard
            }
        }
    }

    private var statusBar: some View {
        Group {
            if let startedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let seconds = didFinish ? frozenSeconds : Int(context.date.timeIntervalSince(startedAt))
                    statusLine(seconds: seconds)
                }
            } else {
                statusLine(seconds: 0)
            }
        }
    }

    private func statusLine(seconds: Int) -> some View {
        let report = puzzle.map(analysis(for:)) ?? .empty
        let remaining = (puzzle?.size ?? launch.size) * (puzzle?.size ?? launch.size) - report.filledCount
        let conflictCount = report.duplicates.count + report.brokenCageIDs.count
        return HStack {
            Text(launch.isDaily ? "Today" : launch.difficulty.title)
            Spacer()
            if didFinish {
                Text("Solved")
                    .foregroundStyle(KenDokuColor.clay)
            } else if highlightMistakes && conflictCount > 0 {
                Text("Check highlighted cells")
                    .foregroundStyle(KenDokuColor.clay)
            } else {
                Text("\(remaining) left")
            }
            Text(Self.clock(seconds))
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func numberPad(size: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(1...size, id: \.self) { number in
                Button {
                    pressNumber(number)
                } label: {
                    Text("\(number)")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.glass)
                .disabled(didFinish)
            }
        }
    }

    private var toolRow: some View {
        HStack(spacing: 8) {
            toolButton(notesMode ? "Notes On" : "Notes", systemImage: notesMode ? "pencil.circle.fill" : "pencil") {
                notesMode.toggle()
            }
            toolButton("Undo", systemImage: "arrow.uturn.backward") {
                undo()
            }
            .disabled(undoStack.isEmpty || didFinish)
            toolButton("Erase", systemImage: "delete.left") {
                erase()
            }
            .disabled(didFinish)
            toolButton("Hint", systemImage: "lightbulb") {
                useHint()
            }
            .disabled(didFinish)
        }
    }

    private func toolButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.glass)
    }

    private var winCard: some View {
        ZStack {
            Color.black.opacity(0.35)
            VStack(spacing: 14) {
                Text("Solved")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(Self.clock(frozenSeconds))
                    .font(.title2.monospacedDigit())
                if usedHint {
                    Text("A hint was used, so this time is not saved as a best.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button {
                    hideWinCard = true
                } label: {
                    Text("Show Board")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                if launch.isDaily {
                    Button("Done", action: dismiss.callAsFunction)
                        .buttonStyle(.glassProminent)
                        .buttonSizing(.flexible)
                } else {
                    Button("Play Again") { loadID += 1 }
                        .buttonStyle(.glassProminent)
                        .buttonSizing(.flexible)
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
    }

    private func analysis(for puzzle: Puzzle) -> BoardAnalysis {
        guard entries.count == puzzle.size else { return .empty }
        return KenKenRules.analyze(entries: entries, puzzle: puzzle)
    }

    private func loadPuzzle() async {
        if installedID == loadID, puzzle != nil { return }
        let token = loadID
        isLoading = true
        let size = launch.size
        let difficulty = launch.difficulty
        let seed = launch.seed
        let generated = await Task.detached {
            KenKenGenerator.generate(size: size, difficulty: difficulty, seed: seed)
        }.value
        guard !Task.isCancelled, token == loadID else { return }
        install(generated, token: token)
    }

    private func install(_ generated: Puzzle, token: Int) {
        puzzle = generated
        entries = Self.blankEntries(size: generated.size)
        notes = Self.blankNotes(size: generated.size)
        selection = CellIndex(row: 0, column: 0)
        undoStack = []
        notesMode = false
        didFinish = false
        usedHint = false
        hideWinCard = false
        startedAt = .now
        frozenSeconds = 0
        installedID = token
        isLoading = false
    }

    private func pressNumber(_ number: Int) {
        guard let puzzle, !didFinish, (1...puzzle.size).contains(number) else { return }
        let cell = selection ?? firstEmpty(in: puzzle)
        guard let cell else { return }
        selection = cell
        if notesMode, entries[cell.row][cell.column] == nil {
            toggleNote(number, at: cell)
        } else {
            write(number, at: cell)
        }
    }

    private func write(_ value: Int, at cell: CellIndex) {
        guard !didFinish else { return }
        let previousValue = entries[cell.row][cell.column]
        let previousNotes = notes[cell.row][cell.column]
        guard previousValue != value else { return }
        undoStack.append(Move(row: cell.row, column: cell.column, value: previousValue, notes: previousNotes))
        entries[cell.row][cell.column] = value
        notes[cell.row][cell.column] = []
        finishIfNeeded()
    }

    private func toggleNote(_ number: Int, at cell: CellIndex) {
        var cellNotes = notes[cell.row][cell.column]
        let previous = cellNotes
        if cellNotes.contains(number) {
            cellNotes.remove(number)
        } else {
            cellNotes.insert(number)
        }
        undoStack.append(Move(row: cell.row, column: cell.column, value: nil, notes: previous))
        notes[cell.row][cell.column] = cellNotes
    }

    private func erase() {
        guard let cell = selection, !didFinish else { return }
        let previousValue = entries[cell.row][cell.column]
        let previousNotes = notes[cell.row][cell.column]
        guard previousValue != nil || !previousNotes.isEmpty else { return }
        undoStack.append(Move(row: cell.row, column: cell.column, value: previousValue, notes: previousNotes))
        entries[cell.row][cell.column] = nil
        notes[cell.row][cell.column] = []
    }

    private func undo() {
        guard !didFinish, let move = undoStack.popLast() else { return }
        entries[move.row][move.column] = move.value
        notes[move.row][move.column] = move.notes
        selection = CellIndex(row: move.row, column: move.column)
    }

    private func useHint() {
        guard let puzzle, !didFinish else { return }
        let cell: CellIndex?
        if let selection, entries[selection.row][selection.column] == nil {
            cell = selection
        } else {
            cell = firstEmpty(in: puzzle)
        }
        guard let cell else { return }
        usedHint = true
        selection = cell
        write(puzzle.solution[cell.row][cell.column], at: cell)
    }

    private func finishIfNeeded() {
        guard let puzzle, !didFinish else { return }
        guard analysis(for: puzzle).isSolved else { return }
        didFinish = true
        hideWinCard = false
        frozenSeconds = Int(Date().timeIntervalSince(startedAt ?? .now))
        stats.recordWin(seconds: frozenSeconds, launch: launch, countsForBestTime: !usedHint)
    }

    private func firstEmpty(in puzzle: Puzzle) -> CellIndex? {
        for row in 0..<puzzle.size {
            for column in 0..<puzzle.size where entries[row][column] == nil {
                return CellIndex(row: row, column: column)
            }
        }
        return nil
    }

    private func nudge(row rowDelta: Int, column columnDelta: Int) {
        guard let puzzle else { return }
        let current = selection ?? CellIndex(row: 0, column: 0)
        let row = min(max(current.row + rowDelta, 0), puzzle.size - 1)
        let column = min(max(current.column + columnDelta, 0), puzzle.size - 1)
        selection = CellIndex(row: row, column: column)
    }

    private func requestClear() {
        guard puzzle != nil else { return }
        if didFinish || hasProgress {
            confirmClear = true
        }
    }

    private func requestNewPuzzle() {
        if didFinish || hasProgress {
            confirmNew = true
        } else {
            loadID += 1
        }
    }

    private var hasProgress: Bool {
        entries.contains { row in row.contains { $0 != nil } }
            || notes.contains { row in row.contains { !$0.isEmpty } }
    }

    private func clearBoard() {
        guard let puzzle else { return }
        entries = Self.blankEntries(size: puzzle.size)
        notes = Self.blankNotes(size: puzzle.size)
        undoStack = []
        notesMode = false
        didFinish = false
        usedHint = false
        hideWinCard = false
        startedAt = .now
        frozenSeconds = 0
        selection = CellIndex(row: 0, column: 0)
    }

    private static func blankEntries(size: Int) -> [[Int?]] {
        Array(repeating: Array(repeating: nil, count: size), count: size)
    }

    private static func blankNotes(size: Int) -> [[Set<Int>]] {
        Array(repeating: Array(repeating: Set<Int>(), count: size), count: size)
    }

    private static func clock(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}

private struct Move {
    var row: Int
    var column: Int
    var value: Int?
    var notes: Set<Int>
}

private struct KenKenBoard: View {
    let puzzle: Puzzle
    let entries: [[Int?]]
    let notes: [[Set<Int>]]
    let selection: CellIndex?
    let analysis: BoardAnalysis
    let showMistakes: Bool
    let onSelect: (CellIndex) -> Void

    private enum Ink {
        static let paper = Color(red: 0.97, green: 0.94, blue: 0.89)
        static let line = Color(red: 0.11, green: 0.12, blue: 0.14)
        static let clue = Color(red: 0.55, green: 0.24, blue: 0.16)
        static let conflict = Color(red: 0.72, green: 0.16, blue: 0.14)
        static let selected = Color(red: 0.93, green: 0.45, blue: 0.27).opacity(0.34)
        static let peer = Color(red: 0.93, green: 0.45, blue: 0.27).opacity(0.12)
        static let conflictFill = Color(red: 0.76, green: 0.18, blue: 0.16).opacity(0.24)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<puzzle.size, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<puzzle.size, id: \.self) { column in
                        cellButton(row: row, column: column)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(Self.cageLineWidth / 2)
        .background(Ink.paper)
        .overlay { borderCanvas.allowsHitTesting(false) }
    }

    /// Cage dividers and the outer border share this width. Half of it sits outside the cells.
    private static let cageLineWidth: CGFloat = 3

    private func cellButton(row: Int, column: Int) -> some View {
        let index = CellIndex(row: row, column: column)
        return Button {
            onSelect(index)
        } label: {
            GeometryReader { geo in
                cellFace(index, side: min(geo.size.width, geo.size.height))
            }
            .background(fill(index))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(label(for: index))
        .accessibilityAddTraits(selection == index ? .isSelected : [])
    }

    private var borderCanvas: some View {
        Canvas { context, size in
            var thin = Path()
            var heavy = Path()
            let count = puzzle.size
            let inset = Self.cageLineWidth / 2
            let cellWidth = (size.width - Self.cageLineWidth) / CGFloat(count)
            let cellHeight = (size.height - Self.cageLineWidth) / CGFloat(count)

            for row in 0..<count {
                for column in 0...count {
                    let cageEdge = column == 0 || column == count
                        || puzzle.cageIDs[row][column - 1] != puzzle.cageIDs[row][column]
                    var segment = Path()
                    let x = inset + CGFloat(column) * cellWidth
                    let y = inset + CGFloat(row) * cellHeight
                    segment.move(to: CGPoint(x: x, y: y))
                    segment.addLine(to: CGPoint(x: x, y: y + cellHeight))
                    if cageEdge {
                        heavy.addPath(segment)
                    } else {
                        thin.addPath(segment)
                    }
                }
            }

            for column in 0..<count {
                for row in 0...count {
                    let cageEdge = row == 0 || row == count
                        || puzzle.cageIDs[row - 1][column] != puzzle.cageIDs[row][column]
                    var segment = Path()
                    let x = inset + CGFloat(column) * cellWidth
                    let y = inset + CGFloat(row) * cellHeight
                    segment.move(to: CGPoint(x: x, y: y))
                    segment.addLine(to: CGPoint(x: x + cellWidth, y: y))
                    if cageEdge {
                        heavy.addPath(segment)
                    } else {
                        thin.addPath(segment)
                    }
                }
            }

            context.stroke(thin, with: .color(Ink.line.opacity(0.22)), lineWidth: 1)
            context.stroke(
                heavy,
                with: .color(Ink.line),
                style: StrokeStyle(lineWidth: Self.cageLineWidth, lineCap: .square)
            )
        }
    }

    private func cellFace(_ cell: CellIndex, side: CGFloat) -> some View {
        let value = entries[cell.row][cell.column]
        let clue = puzzle.clues[cell]
        return ZStack(alignment: .topLeading) {
            if let value {
                Text("\(value)")
                    .font(.system(size: side * 0.42, weight: .medium, design: .rounded))
                    .foregroundStyle(isConflict(cell) ? Ink.conflict : Ink.line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: clue == nil ? 0 : side * 0.05)
            } else if !notes[cell.row][cell.column].isEmpty {
                noteGrid(notes[cell.row][cell.column], side: side, hasClue: clue != nil)
            }

            if let clue {
                Text(clue)
                    .font(.system(size: max(9, side * 0.2), weight: .bold, design: .rounded))
                    .foregroundStyle(Ink.clue)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.leading, side * 0.07)
                    .padding(.top, side * 0.04)
            }
        }
    }

    private func noteGrid(_ marks: Set<Int>, side: CGFloat, hasClue: Bool) -> some View {
        let columns = puzzle.size <= 4 ? 2 : 3
        let rows = Int((Double(puzzle.size) / Double(columns)).rounded(.up))
        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { column in
                        let number = row * columns + column + 1
                        Text(number <= puzzle.size && marks.contains(number) ? "\(number)" : " ")
                            .font(.system(size: side * 0.16, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .foregroundStyle(Ink.line.opacity(0.62))
        .padding(.top, hasClue ? side * 0.24 : side * 0.08)
        .padding(.horizontal, side * 0.08)
        .padding(.bottom, side * 0.06)
    }

    private func fill(_ cell: CellIndex) -> Color {
        if isConflict(cell) { return Ink.conflictFill }
        if selection == cell { return Ink.selected }
        guard let selection else { return .clear }
        if cell.row == selection.row || cell.column == selection.column {
            return Ink.peer
        }
        if let selectedValue = entries[selection.row][selection.column],
           entries[cell.row][cell.column] == selectedValue {
            return Ink.peer
        }
        return .clear
    }

    private func isConflict(_ cell: CellIndex) -> Bool {
        guard showMistakes else { return false }
        if analysis.duplicates.contains(cell) { return true }
        let cageID = puzzle.cageIDs[cell.row][cell.column]
        return analysis.brokenCageIDs.contains(cageID)
    }

    private func label(for cell: CellIndex) -> String {
        var parts = ["Row \(cell.row + 1), column \(cell.column + 1)"]
        if let value = entries[cell.row][cell.column] {
            parts.append("\(value)")
        } else {
            parts.append("empty")
        }
        if let clue = puzzle.clues[cell] {
            parts.append("cage \(clue)")
        }
        if isConflict(cell) {
            parts.append("needs attention")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        GamePlayView(launch: GameLaunch(size: 4, difficulty: .easy, seed: 1, isDaily: false, id: 1))
    }
    .environment(PlayerStats.preview)
}
