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
    @Environment(\.appTheme) private var theme
    @AppStorage(GameSettings.highlightMistakes) private var highlightMistakes = true
    @AppStorage(GameSettings.allowAdd) private var allowAdd = true
    @AppStorage(GameSettings.allowSubtract) private var allowSubtract = true
    @AppStorage(GameSettings.allowMultiply) private var allowMultiply = true
    @AppStorage(GameSettings.allowDivide) private var allowDivide = true
    @AppStorage(GameSettings.hideOperators) private var hideOperators = false

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
                    .tint(theme.accent)
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
        GeometryReader { proxy in
            Group {
                if prefersSideControls(in: proxy.size) {
                    widePlayfield(puzzle, in: proxy.size)
                } else {
                    stackedPlayfield(puzzle)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay {
                if didFinish && !hideWinCard {
                    winCard
                }
            }
        }
    }

    /// Landscape, including the closed Duo, keeps the controls beside the board so the grid can use the height.
    private func prefersSideControls(in size: CGSize) -> Bool {
        guard size.width > size.height else { return false }
        let column = sideColumnWidth(for: size.width)
        let boardSide = min(size.width - column - 48, size.height - 64)
        return boardSide >= 220
    }

    private func sideColumnWidth(for width: CGFloat) -> CGFloat {
        width >= 900 ? 208 : 164
    }

    private func stackedPlayfield(_ puzzle: Puzzle) -> some View {
        VStack(spacing: 14) {
            statusBar
            board(puzzle)
                .frame(maxWidth: 640)
            numberPad(size: puzzle.size)
            toolRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func widePlayfield(_ puzzle: Puzzle, in size: CGSize) -> some View {
        let column = sideColumnWidth(for: size.width)
        return VStack(spacing: 12) {
            statusBar
            GeometryReader { proxy in
                let side = max(0, min(proxy.size.width - column - 16, proxy.size.height))
                HStack(alignment: .center, spacing: 16) {
                    board(puzzle)
                        .frame(width: side, height: side)
                    sideControls(size: puzzle.size, height: proxy.size.height)
                        .frame(width: column, height: proxy.size.height)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func board(_ puzzle: Puzzle) -> some View {
        KenKenBoard(
            puzzle: puzzle,
            entries: entries,
            notes: notes,
            selection: selection,
            analysis: analysis(for: puzzle),
            showMistakes: highlightMistakes,
            onSelect: { selection = $0 }
        )
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }

    private func sideControls(size: Int, height: CGFloat) -> some View {
        let numberRows = CGFloat((size + 1) / 2)
        let toolCount: CGFloat = 4
        let gridSpacing: CGFloat = 6
        let toolSpacing: CGFloat = 6
        let sectionSpacing: CGFloat = 8
        let gaps = gridSpacing * max(0, numberRows - 1) + sectionSpacing + toolSpacing * (toolCount - 1)
        let usable = max(0, height - gaps)
        let share = usable / (numberRows + toolCount)
        let toolHeight = min(48, share)
        let numberHeight = min(46, (usable - toolHeight * toolCount) / numberRows)
        return VStack(spacing: sectionSpacing) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: gridSpacing
            ) {
                ForEach(1...size, id: \.self) { number in
                    numberButton(number, height: numberHeight)
                }
            }
            VStack(spacing: toolSpacing) {
                toolButton(notesMode ? "Notes On" : "Notes", systemImage: notesMode ? "pencil.circle.fill" : "pencil", height: toolHeight) {
                    notesMode.toggle()
                }
                toolButton("Undo", systemImage: "arrow.uturn.backward", height: toolHeight) {
                    undo()
                }
                .disabled(undoStack.isEmpty || didFinish)
                toolButton("Erase", systemImage: "delete.left", height: toolHeight) {
                    erase()
                }
                .disabled(didFinish)
                toolButton("Hint", systemImage: "lightbulb", height: toolHeight) {
                    useHint()
                }
                .disabled(didFinish)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
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
            Text(statusTitle)
            Spacer()
            if didFinish {
                Text("Solved")
                    .foregroundStyle(theme.accent)
            } else if highlightMistakes && conflictCount > 0 {
                Text("Check highlighted cells")
                    .foregroundStyle(theme.accent)
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
        HStack(spacing: size >= 8 ? 4 : 8) {
            ForEach(1...size, id: \.self) { number in
                numberButton(number, height: 46)
            }
        }
    }

    private func numberButton(_ number: Int, height: CGFloat) -> some View {
        Button {
            pressNumber(number)
        } label: {
            Text("\(number)")
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 12))
        .buttonSizing(.flexible)
        .disabled(didFinish)
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
        height: CGFloat = 48,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 12))
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
                .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 14))

                if launch.isDaily {
                    Button("Done", action: dismiss.callAsFunction)
                        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.tint(Color.accentColor).interactive(), cornerRadius: 14))
                        .buttonSizing(.flexible)
                } else {
                    Button("Play Again") { loadID += 1 }
                        .buttonStyle(KenDokuGlassButtonStyle(glass: .regular.tint(Color.accentColor).interactive(), cornerRadius: 14))
                        .buttonSizing(.flexible)
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
    }

    private var selectedRules: OperatorRules {
        OperatorRules(
            add: allowAdd,
            subtract: allowSubtract,
            multiply: allowMultiply,
            divide: allowDivide,
            hidesOperators: hideOperators
        )
    }

    private var statusTitle: String {
        if launch.isDaily { return "Today" }
        if puzzle?.rules.hidesOperators == true { return "No-op" }
        return launch.difficulty.title
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
        let rules = launch.isDaily ? OperatorRules.standard : selectedRules
        let generated = await Task.detached {
            KenKenGenerator.generate(size: size, difficulty: difficulty, seed: seed, rules: rules)
        }.value
        guard !Task.isCancelled, token == loadID else { return }
        install(generated, token: token)
    }

    private func install(_ generated: Puzzle, token: Int) {
        puzzle = generated
        entries = generated.startingEntries()
        notes = Self.blankNotes(size: generated.size)
        selection = firstEmpty(in: generated) ?? CellIndex(row: 0, column: 0)
        undoStack = []
        notesMode = false
        didFinish = false
        usedHint = false
        hideWinCard = false
        startedAt = .now
        frozenSeconds = 0
        installedID = token
        isLoading = false
        finishIfNeeded()
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
        guard !didFinish, !isGiven(cell) else { return }
        let previousValue = entries[cell.row][cell.column]
        let previousNotes = notes[cell.row][cell.column]
        guard previousValue != value else { return }
        undoStack.append(Move(row: cell.row, column: cell.column, value: previousValue, notes: previousNotes))
        entries[cell.row][cell.column] = value
        notes[cell.row][cell.column] = []
        finishIfNeeded()
    }

    private func toggleNote(_ number: Int, at cell: CellIndex) {
        guard !isGiven(cell) else { return }
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
        guard let cell = selection, !didFinish, !isGiven(cell) else { return }
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
        guard let puzzle else { return false }
        if entries != puzzle.startingEntries() { return true }
        return notes.contains { row in row.contains { !$0.isEmpty } }
    }

    private func isGiven(_ cell: CellIndex) -> Bool {
        puzzle?.isGiven(cell) ?? false
    }

    private func clearBoard() {
        guard let puzzle else { return }
        entries = puzzle.startingEntries()
        notes = Self.blankNotes(size: puzzle.size)
        undoStack = []
        notesMode = false
        didFinish = false
        usedHint = false
        hideWinCard = false
        startedAt = .now
        frozenSeconds = 0
        selection = firstEmpty(in: puzzle) ?? CellIndex(row: 0, column: 0)
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

    @Environment(\.appTheme) private var theme

    private static let conflict = Color(red: 0.72, green: 0.16, blue: 0.14)
    private static let conflictFill = Color(red: 0.76, green: 0.18, blue: 0.16).opacity(0.24)

    var body: some View {
        // The clear square owns the layout. A 9×9 grid's own ideal size is taller than that square
        // in the side-by-side layout, and the paper was filling the extra height.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
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
            }
            .padding(Self.cageLineWidth / 2)
            .background(theme.paper)
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
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .background(fill(index))
        }
        .buttonStyle(KenDokuHitButtonStyle())
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

            context.stroke(thin, with: .color(theme.boardLine.opacity(0.22)), lineWidth: 1)
            context.stroke(
                heavy,
                with: .color(theme.boardLine),
                style: StrokeStyle(lineWidth: Self.cageLineWidth, lineCap: .square)
            )
        }
    }

    private func cellFace(_ cell: CellIndex, side: CGFloat) -> some View {
        let value = entries[cell.row][cell.column]
        let given = puzzle.isGiven(cell)
        let clue = given ? nil : puzzle.clues[cell]
        // The clue is its own overlay. Sharing a stack with the digit let the corner label shift the number down.
        return Color.clear
            .overlay {
                if let value {
                    Text("\(value)")
                        .font(.system(size: side * 0.42, weight: given ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isConflict(cell) ? Self.conflict : theme.boardLine)
                } else if !notes[cell.row][cell.column].isEmpty {
                    noteGrid(notes[cell.row][cell.column], side: side, hasClue: clue != nil)
                }
            }
            .overlay(alignment: .topLeading) {
                if let clue {
                    Text(clue)
                        .font(.system(size: max(9, side * 0.2), weight: .bold, design: .rounded))
                        .foregroundStyle(theme.clue)
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
        .foregroundStyle(theme.boardLine.opacity(0.62))
        .padding(.top, hasClue ? side * 0.24 : side * 0.08)
        .padding(.horizontal, side * 0.08)
        .padding(.bottom, side * 0.06)
    }

    private func fill(_ cell: CellIndex) -> Color {
        if isConflict(cell) { return Self.conflictFill }
        if selection == cell { return theme.selectedFill }
        guard let selection else { return .clear }
        if cell.row == selection.row || cell.column == selection.column {
            return theme.peerFill
        }
        if let selectedValue = entries[selection.row][selection.column],
           entries[cell.row][cell.column] == selectedValue {
            return theme.peerFill
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
        if puzzle.isGiven(cell), let value = entries[cell.row][cell.column] {
            parts.append("given \(value)")
        } else if let value = entries[cell.row][cell.column] {
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
            .kendokuScreen()
    }
    .kendokuScreen()
    .environment(PlayerStats.preview)
}
