//
//  GamePlayView.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/7/26.
//

import SwiftUI

struct GamePlayView: View {
    let launch: GameLaunch

    @Environment(PlayerStats.self) private var stats
    @Environment(ActiveGame.self) private var activeGame
    @Environment(GameDeck.self) private var gameDeck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme
    @AppStorage(GameSettings.mistakeHighlight) private var highlightRaw = ""
    @AppStorage(GameSettings.allowAdd) private var allowAdd = true
    @AppStorage(GameSettings.allowSubtract) private var allowSubtract = true
    @AppStorage(GameSettings.allowMultiply) private var allowMultiply = true
    @AppStorage(GameSettings.allowDivide) private var allowDivide = true
    @AppStorage(GameSettings.hideOperators) private var hideOperators = false
    @AppStorage(GameSettings.leftHand) private var leftHand = false

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
    @State private var madeError = false
    @State private var hideWinCard = false
    @State private var startedAt: Date?
    @State private var bankedSeconds = 0
    @State private var frozenSeconds = 0
    @State private var confirmClear = false
    @State private var confirmNew = false
    @State private var showPlaySettings = false
    @State private var showCombinations = false
    @State private var dismissedCombos: [Int: [CageCombo]] = [:]

    var body: some View {
        playScreen
    }

    private var playScreen: some View {
        dialogs(presence(storedChanges(chrome(playStack))))
    }

    private func chrome<V: View>(_ view: V) -> some View {
        view
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(launch.isDaily ? "Daily Puzzle" : "Mathdoku")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbar }
            #if os(iOS)
            .sensoryFeedback(.success, trigger: didFinish)
            #endif
            .modifier(PlayKeyboardModifier(
                size: launch.size,
                onNumber: pressNumber,
                onErase: erase,
                onNudge: { row, column in
                    nudge(row: row, column: column)
                }
            ))
    }

    private func storedChanges<V: View>(_ view: V) -> some View {
        view
            .task(id: loadID) {
                await loadPuzzle()
            }
            .onChange(of: entries) { persistProgress() }
            .onChange(of: notes) { persistProgress() }
            .onChange(of: selection) { persistProgress() }
            .onChange(of: notesMode) { persistProgress() }
            .onChange(of: dismissedCombos) { persistProgress() }
    }

    private func presence<V: View>(_ view: V) -> some View {
        view
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    resumeClockIfNeeded()
                } else {
                    pauseClock()
                    persistProgress()
                }
            }
            .onAppear {
                resumeClockIfNeeded()
            }
            .onDisappear {
                pauseClock()
                persistProgress()
            }
    }

    private func dialogs<V: View>(_ view: V) -> some View {
        view
            .confirmationDialog("Clear this board?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear Board", role: .destructive, action: clearBoard)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Numbers, notes, and removed combinations on this puzzle will be erased.")
            }
            .confirmationDialog("Start a new puzzle?", isPresented: $confirmNew, titleVisibility: .visible) {
                Button("New Puzzle", role: .destructive) { loadID += 1 }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This board will be replaced.")
            }
            .sheet(isPresented: $showPlaySettings) {
                PlaySettingsSheet()
            }
            .sheet(isPresented: $showCombinations) {
                combinationSheet
            }
    }

    private func resumeClockIfNeeded() {
        if startedAt == nil, puzzle != nil, !didFinish, !isLoading {
            startedAt = .now
        }
    }

    private var playStack: some View {
        ZStack {
            MathdokuBackground()
            if isLoading || puzzle == nil {
                ProgressView("Generating the board...")
                    .tint(theme.accent)
            } else if let puzzle {
                playfield(puzzle)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button("Clear", systemImage: "arrow.counterclockwise", action: requestClear)
                .disabled(puzzle == nil || dailyIsClosed)
            if !launch.isDaily {
                Button("New Puzzle", systemImage: "plus", action: requestNewPuzzle)
                    .disabled(isLoading)
            }
            Button("Settings", systemImage: "gearshape") {
                showPlaySettings = true
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

    /// Landscape, including the closed outer display, keeps the controls beside the board so the grid can use the height.
    private func prefersSideControls(in size: CGSize) -> Bool {
        guard size.width > size.height else { return false }
        let column = sideColumnWidth(for: size.width)
        let boardSide = min(size.width - column - 24, size.height - 28)
        return boardSide >= 160
    }

    private func sideColumnWidth(for width: CGFloat) -> CGFloat {
        width >= 900 ? 248 : 200
    }

    private func stackedPlayfield(_ puzzle: Puzzle) -> some View {
        VStack(spacing: 14) {
            statusBar
            board(puzzle)
                .frame(maxWidth: 640)
            toolRow
            numberPad(size: puzzle.size)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func widePlayfield(_ puzzle: Puzzle, in size: CGSize) -> some View {
        let column = sideColumnWidth(for: size.width)
        return VStack(spacing: 6) {
            statusBar
            GeometryReader { proxy in
                let side = max(0, min(proxy.size.width - column - 8, proxy.size.height))
                HStack(alignment: .center, spacing: 0) {
                    if leftHand {
                        sideControls(size: puzzle.size, height: proxy.size.height)
                            .frame(width: column, height: proxy.size.height)
                    }
                    board(puzzle)
                        .frame(width: side, height: side)
                        .frame(maxWidth: .infinity)
                    if !leftHand {
                        sideControls(size: puzzle.size, height: proxy.size.height)
                            .frame(width: column, height: proxy.size.height)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func board(_ puzzle: Puzzle) -> some View {
        MathdokuBoard(
            puzzle: puzzle,
            entries: entries,
            notes: notes,
            selection: selection,
            analysis: analysis(for: puzzle),
            highlight: mistakeHighlight,
            onSelect: { selection = $0 }
        )
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }

    private func sideControls(size: Int, height: CGFloat) -> some View {
        let spacing: CGFloat = 6
        let numberCount = CGFloat(max(size, 1))
        let numberHeight = max(0, (height - spacing * (numberCount - 1)) / numberCount)
        return HStack(alignment: .center, spacing: 8) {
            if !leftHand {
                toolColumn(height: height)
                    .frame(maxWidth: .infinity)
            }
            VStack(spacing: spacing) {
                ForEach(1...size, id: \.self) { number in
                    numberButton(number, height: numberHeight)
                }
            }
            .frame(maxWidth: .infinity)
            if leftHand {
                toolColumn(height: height)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func toolColumn(height: CGFloat?) -> some View {
        let spacing: CGFloat = 6
        let toolHeight: CGFloat = {
            guard let height else { return 48 }
            return max(0, (height - spacing * 4) / 5)
        }()
        return VStack(spacing: spacing) {
            toolButton(
                notesMode ? "Notes On" : "Notes",
                systemImage: notesMode ? "pencil.circle.fill" : "pencil",
                height: toolHeight
            ) {
                notesMode.toggle()
            }
            toolButton(
                "Undo",
                systemImage: "arrow.uturn.backward",
                height: toolHeight,
                isEnabled: canUndo
            ) {
                undo()
            }
            toolButton("Erase", systemImage: "delete.left", height: toolHeight) {
                erase()
            }
            .disabled(didFinish)
            toolButton(
                "Combos",
                systemImage: "list.number",
                height: toolHeight,
                isEnabled: canShowCombinations
            ) {
                showCombinations = true
            }
            toolButton("Hint", systemImage: "lightbulb", height: toolHeight) {
                useHint()
            }
            .disabled(didFinish)
        }
    }

    private var statusBar: some View {
        Group {
            if let startedAt, !didFinish {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let running = max(0, Int(context.date.timeIntervalSince(startedAt)))
                    statusLine(seconds: bankedSeconds + running)
                }
            } else {
                statusLine(seconds: didFinish ? frozenSeconds : bankedSeconds)
            }
        }
    }

    private func statusLine(seconds: Int) -> some View {
        Text(Self.clock(seconds))
            .monospacedDigit()
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
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
        .buttonStyle(MathdokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 12))
        .buttonSizing(.flexible)
        .disabled(didFinish)
    }

    private var toolRow: some View {
        HStack(spacing: 8) {
            toolButton(notesMode ? "Notes On" : "Notes", systemImage: notesMode ? "pencil.circle.fill" : "pencil") {
                notesMode.toggle()
            }
            toolButton("Undo", systemImage: "arrow.uturn.backward", isEnabled: canUndo) {
                undo()
            }
            toolButton("Erase", systemImage: "delete.left") {
                erase()
            }
            .disabled(didFinish)
            toolButton("Combos", systemImage: "list.number", isEnabled: canShowCombinations) {
                showCombinations = true
            }
            toolButton("Hint", systemImage: "lightbulb") {
                useHint()
            }
            .disabled(didFinish)
        }
    }

    private var canUndo: Bool {
        !undoStack.isEmpty && !didFinish
    }

    private func toolButton(
        _ title: String,
        systemImage: String,
        height: CGFloat = 48,
        isEnabled: Bool = true,
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
        .buttonStyle(
            MathdokuGlassButtonStyle(
                glass: isEnabled ? .regular.interactive() : .regular,
                cornerRadius: 12
            )
        )
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
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
                winButton("Show Board", prominent: false) {
                    hideWinCard = true
                }
                if launch.isDaily {
                    winButton("Done", prominent: true) {
                        dismiss()
                    }
                } else {
                    winButton("Play Again", prominent: true) {
                        loadID += 1
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func winButton(_ title: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(prominent ? Color.accentColor : Color.white.opacity(0.16))
                }
        }
        .buttonStyle(MathdokuHitButtonStyle())
    }

    private var mistakeHighlight: MistakeHighlight {
        GameSettings.resolvedMistakeHighlight(stored: highlightRaw)
    }

    private var selectedRules: OperatorRules {
        OperatorRules(
            add: allowAdd,
            subtract: allowSubtract,
            multiply: allowMultiply,
            divide: allowDivide,
            hidesOperators: hideOperators
        ).normalized
    }

    private func analysis(for puzzle: Puzzle) -> BoardAnalysis {
        guard entries.count == puzzle.size else { return .empty }
        return MathdokuRules.analyze(entries: entries, puzzle: puzzle)
    }

    private func loadPuzzle() async {
        if installedID == loadID, puzzle != nil { return }
        let token = loadID
        if token == 0, restore(token: token) { return }
        if launch.isDaily, stats.completedDailyToday {
            isLoading = false
            dismiss()
            return
        }

        // A random game can use the board built while the app was open. Daily and seeded boards stay on their own seed.
        if launch.seed == nil {
            let spec = GameDeck.Spec(size: launch.size, difficulty: launch.difficulty, rules: selectedRules)
            if let ready = gameDeck.takeIfReady(spec) {
                activeGame.clear()
                install(ready.shown(hidingOperators: selectedRules.hidesOperators), token: token)
                return
            }
            isLoading = true
            puzzle = nil
            activeGame.clear()
            let generated = await gameDeck.puzzle(for: spec)
            guard !Task.isCancelled, token == loadID else { return }
            install(generated.shown(hidingOperators: selectedRules.hidesOperators), token: token)
            return
        }

        isLoading = true
        puzzle = nil
        activeGame.clear()
        let size = launch.size
        let difficulty = launch.difficulty
        let seed = launch.seed
        let rules = launch.isDaily ? OperatorRules.standard : selectedRules
        let generated = await Task.detached {
            MathdokuGenerator.generate(size: size, difficulty: difficulty, seed: seed, rules: rules)
        }.value
        guard !Task.isCancelled, token == loadID else { return }
        install(generated, token: token)
    }

    private func restore(token: Int) -> Bool {
        guard let saved = activeGame.game, saved.matches(launch), saved.isPlayable else { return false }
        let restored = saved.puzzle
        puzzle = restored
        entries = alignedEntries(saved.entries, puzzle: restored)
        notes = alignedNotes(saved.notes, size: restored.size)
        if let selection = saved.selection,
           selection.row >= 0, selection.column >= 0,
           selection.row < restored.size, selection.column < restored.size {
            self.selection = selection
        } else {
            selection = firstEmpty(in: restored) ?? CellIndex(row: 0, column: 0)
        }
        undoStack = saved.undo.compactMap { move in
            guard move.row >= 0, move.column >= 0,
                  move.row < restored.size, move.column < restored.size else { return nil }
            return Move(
                row: move.row,
                column: move.column,
                value: move.value,
                notes: move.notes,
                clearedNotes: move.clearedNotes.filter { change in
                    change.row >= 0 && change.column >= 0
                        && change.row < restored.size && change.column < restored.size
                },
                comboDismissal: validDismissal(move.comboDismissal, puzzle: restored),
                comboReset: validComboReset(move.comboReset, puzzle: restored)
            )
        }
        notesMode = saved.notesMode
        dismissedCombos = validDismissedCombos(saved.dismissedCombos, puzzle: restored)
        didFinish = false
        usedHint = saved.usedHint
        madeError = saved.madeError
        hideWinCard = false
        bankedSeconds = max(0, saved.elapsedSeconds)
        startedAt = .now
        frozenSeconds = 0
        installedID = token
        isLoading = false
        return true
    }

    private func install(_ generated: Puzzle, token: Int) {
        puzzle = generated
        entries = generated.startingEntries()
        notes = Self.blankNotes(size: generated.size)
        selection = firstEmpty(in: generated) ?? CellIndex(row: 0, column: 0)
        undoStack = []
        notesMode = false
        dismissedCombos = [:]
        showCombinations = false
        didFinish = false
        usedHint = false
        madeError = false
        hideWinCard = false
        bankedSeconds = 0
        startedAt = .now
        frozenSeconds = 0
        installedID = token
        isLoading = false
        stats.recordStart(size: generated.size)
        finishIfNeeded()
        persistProgress()
    }

    private func alignedEntries(_ saved: [[Int?]], puzzle: Puzzle) -> [[Int?]] {
        var grid = puzzle.startingEntries()
        guard saved.count == puzzle.size else { return grid }
        for row in 0..<puzzle.size {
            guard saved[row].count == puzzle.size else { continue }
            for column in 0..<puzzle.size {
                let cell = CellIndex(row: row, column: column)
                if puzzle.isGiven(cell) { continue }
                grid[row][column] = saved[row][column]
            }
        }
        return grid
    }

    private func alignedNotes(_ saved: [[Set<Int>]], size: Int) -> [[Set<Int>]] {
        guard saved.count == size, saved.allSatisfy({ $0.count == size }) else {
            return Self.blankNotes(size: size)
        }
        return saved
    }

    private func elapsedSeconds(at date: Date = .now) -> Int {
        guard let startedAt else { return bankedSeconds }
        return bankedSeconds + max(0, Int(date.timeIntervalSince(startedAt)))
    }

    private func pauseClock() {
        guard !didFinish else { return }
        bankedSeconds = elapsedSeconds()
        startedAt = nil
    }

    private func persistProgress() {
        guard !didFinish, !isLoading, let puzzle else { return }
        let saved = SavedGame(
            size: launch.size,
            difficulty: launch.difficulty,
            seed: launch.seed,
            isDaily: launch.isDaily,
            id: launch.id,
            puzzle: puzzle,
            entries: entries,
            notes: notes,
            selection: selection,
            undo: undoStack.map {
                SavedMove(
                    row: $0.row,
                    column: $0.column,
                    value: $0.value,
                    notes: $0.notes,
                    clearedNotes: $0.clearedNotes,
                    comboDismissal: $0.comboDismissal,
                    comboReset: $0.comboReset
                )
            },
            notesMode: notesMode,
            usedHint: usedHint,
            madeError: madeError,
            elapsedSeconds: elapsedSeconds(),
            dismissedCombos: dismissedCombos
        )
        activeGame.save(saved)
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
        let clearedNotes = matchingNotes(of: value, around: cell)
        undoStack.append(
            Move(
                row: cell.row,
                column: cell.column,
                value: previousValue,
                notes: previousNotes,
                clearedNotes: clearedNotes
            )
        )
        if let puzzle, puzzle.solution[cell.row][cell.column] != value {
            madeError = true
        }
        entries[cell.row][cell.column] = value
        notes[cell.row][cell.column] = []
        for change in clearedNotes {
            var cellNotes = notes[change.row][change.column]
            cellNotes.remove(value)
            notes[change.row][change.column] = cellNotes
        }
        finishIfNeeded()
    }

    /// Notes in this row and column that still contain `value`. The placed cell is excluded.
    /// A wrong digit clears them too. Cages are left alone, since a digit may repeat there.
    private func matchingNotes(of value: Int, around cell: CellIndex) -> [SavedNoteChange] {
        guard let puzzle else { return [] }
        var changes: [SavedNoteChange] = []
        func capture(row: Int, column: Int) {
            guard row != cell.row || column != cell.column else { return }
            guard notes.indices.contains(row), notes[row].indices.contains(column) else { return }
            let cellNotes = notes[row][column]
            guard cellNotes.contains(value) else { return }
            changes.append(SavedNoteChange(row: row, column: column, notes: cellNotes))
        }
        for column in 0..<puzzle.size {
            capture(row: cell.row, column: column)
        }
        for row in 0..<puzzle.size {
            capture(row: row, column: cell.column)
        }
        return changes
    }

    private func toggleNote(_ number: Int, at cell: CellIndex) {
        guard !didFinish, !isGiven(cell) else { return }
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
        for change in move.clearedNotes {
            guard notes.indices.contains(change.row), notes[change.row].indices.contains(change.column) else { continue }
            notes[change.row][change.column] = change.notes
        }
        if let dismissal = move.comboDismissal {
            dismissedCombos[dismissal.cageID]?.removeAll { $0.canonical == CageCombo(digits: dismissal.digits).canonical }
            if dismissedCombos[dismissal.cageID]?.isEmpty == true {
                dismissedCombos[dismissal.cageID] = nil
            }
        }
        if let reset = move.comboReset {
            dismissedCombos[reset.cageID] = reset.combos
        }
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
        showCombinations = false
        hideWinCard = false
        frozenSeconds = elapsedSeconds()
        startedAt = nil
        stats.recordWin(
            seconds: frozenSeconds,
            launch: launch,
            countsForBestTime: !usedHint,
            perfect: !usedHint && !madeError
        )
        activeGame.clear()
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

    private var dailyIsClosed: Bool {
        launch.isDaily && (didFinish || stats.completedDailyToday)
    }

    private func requestClear() {
        guard puzzle != nil, !dailyIsClosed else { return }
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
        if !dismissedCombos.isEmpty { return true }
        return notes.contains { row in row.contains { !$0.isEmpty } }
    }

    private func isGiven(_ cell: CellIndex) -> Bool {
        puzzle?.isGiven(cell) ?? false
    }

    private func clearBoard() {
        guard let puzzle, !dailyIsClosed else { return }
        entries = puzzle.startingEntries()
        notes = Self.blankNotes(size: puzzle.size)
        undoStack = []
        notesMode = false
        dismissedCombos = [:]
        didFinish = false
        usedHint = false
        madeError = false
        hideWinCard = false
        bankedSeconds = 0
        startedAt = .now
        frozenSeconds = 0
        selection = firstEmpty(in: puzzle) ?? CellIndex(row: 0, column: 0)
    }

    private var canShowCombinations: Bool {
        guard !didFinish, let cage = selectedCage else { return false }
        return cage.cells.count > 1
    }

    private var selectedCage: Cage? {
        guard let puzzle, let selection,
              selection.row >= 0, selection.column >= 0,
              selection.row < puzzle.size, selection.column < puzzle.size
        else { return nil }
        let cageID = puzzle.cageIDs[selection.row][selection.column]
        guard puzzle.cages.indices.contains(cageID) else { return nil }
        return puzzle.cages[cageID]
    }

    @ViewBuilder
    private var combinationSheet: some View {
        if let cage = selectedCage {
            CellGroupSheet(
                cage: cage,
                entries: entries,
                size: cage.cells.isEmpty ? 0 : (puzzle?.size ?? 0),
                hidesOperators: puzzle?.rules.hidesOperators ?? false,
                dismissed: dismissedCombos[cage.id] ?? [],
                onRemove: { combo in dismissCombo(combo, cageID: cage.id) },
                onReset: { resetCombos(cageID: cage.id) },
                onSetNotes: { combos in applyGroupNotes(combos, cage: cage) }
            )
        }
    }

    private func dismissCombo(_ combo: CageCombo, cageID: Int) {
        guard !didFinish, let selection else { return }
        let canonical = combo.canonical
        var list = dismissedCombos[cageID] ?? []
        guard !list.contains(where: { $0.canonical == canonical }) else { return }
        undoStack.append(
            Move(
                row: selection.row,
                column: selection.column,
                value: entries[selection.row][selection.column],
                notes: notes[selection.row][selection.column],
                comboDismissal: SavedComboDismissal(cageID: cageID, digits: canonical.digits)
            )
        )
        list.append(canonical)
        dismissedCombos[cageID] = list
    }

    private func resetCombos(cageID: Int) {
        guard !didFinish, let selection, let list = dismissedCombos[cageID], !list.isEmpty else { return }
        undoStack.append(
            Move(
                row: selection.row,
                column: selection.column,
                value: entries[selection.row][selection.column],
                notes: notes[selection.row][selection.column],
                comboReset: SavedComboReset(cageID: cageID, combos: list)
            )
        )
        dismissedCombos[cageID] = nil
    }

    private func applyGroupNotes(_ combos: [CageCombo], cage: Cage) {
        guard !didFinish, !combos.isEmpty else { return }
        let cells = MathdokuRules.orderedCells(cage.cells)
        var planned: [(CellIndex, Set<Int>)] = []
        for (index, cell) in cells.enumerated() {
            guard notes.indices.contains(cell.row), notes[cell.row].indices.contains(cell.column) else { continue }
            let digits: Set<Int>
            if entries[cell.row][cell.column] == nil {
                digits = Set(combos.compactMap { combo in
                    combo.digits.indices.contains(index) ? combo.digits[index] : nil
                })
            } else {
                digits = []
            }
            guard notes[cell.row][cell.column] != digits else { continue }
            planned.append((cell, digits))
        }
        guard let first = planned.first else { return }
        let rest = planned.dropFirst().map { item in
            SavedNoteChange(row: item.0.row, column: item.0.column, notes: notes[item.0.row][item.0.column])
        }
        undoStack.append(
            Move(
                row: first.0.row,
                column: first.0.column,
                value: nil,
                notes: notes[first.0.row][first.0.column],
                clearedNotes: rest
            )
        )
        for (cell, digits) in planned {
            notes[cell.row][cell.column] = digits
        }
    }

    private func validDismissal(_ dismissal: SavedComboDismissal?, puzzle: Puzzle) -> SavedComboDismissal? {
        guard let dismissal, puzzle.cages.indices.contains(dismissal.cageID) else { return nil }
        let count = puzzle.cages[dismissal.cageID].cells.count
        guard dismissal.digits.count == count,
              dismissal.digits.allSatisfy({ (1...puzzle.size).contains($0) })
        else { return nil }
        return dismissal
    }

    private func validComboReset(_ reset: SavedComboReset?, puzzle: Puzzle) -> SavedComboReset? {
        guard let reset else { return nil }
        let combos = validDismissedCombos([reset.cageID: reset.combos], puzzle: puzzle)[reset.cageID] ?? []
        guard !combos.isEmpty else { return nil }
        return SavedComboReset(cageID: reset.cageID, combos: combos)
    }

    private func validDismissedCombos(_ saved: [Int: [CageCombo]], puzzle: Puzzle) -> [Int: [CageCombo]] {
        var kept: [Int: [CageCombo]] = [:]
        for (cageID, combos) in saved {
            guard puzzle.cages.indices.contains(cageID) else { continue }
            let count = puzzle.cages[cageID].cells.count
            let valid = combos.filter { combo in
                combo.digits.count == count && combo.digits.allSatisfy { (1...puzzle.size).contains($0) }
            }
            if !valid.isEmpty {
                kept[cageID] = valid
            }
        }
        return kept
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
    var clearedNotes: [SavedNoteChange] = []
    var comboDismissal: SavedComboDismissal? = nil
    var comboReset: SavedComboReset? = nil
}

private struct CellGroupSheet: View {
    let cage: Cage
    let entries: [[Int?]]
    let size: Int
    let hidesOperators: Bool
    let dismissed: [CageCombo]
    let onRemove: (CageCombo) -> Void
    let onReset: () -> Void
    let onSetNotes: ([CageCombo]) -> Void

    @Environment(\.dismiss) private var dismiss

    private var positional: [CageCombo] {
        MathdokuRules.combinations(cage: cage, entries: entries, size: size)
    }

    private var possible: [CageCombo] {
        Self.uniqueSorted(positional)
    }

    private var visiblePositional: [CageCombo] {
        let hidden = Set(dismissed.map(\.canonical))
        return positional.filter { !hidden.contains($0.canonical) }
    }

    private var visible: [CageCombo] {
        Self.uniqueSorted(visiblePositional)
    }

    private static func uniqueSorted(_ combos: [CageCombo]) -> [CageCombo] {
        var seen = Set<CageCombo>()
        var unique: [CageCombo] = []
        for combo in combos {
            let canonical = combo.canonical
            if seen.insert(canonical).inserted {
                unique.append(canonical)
            }
        }
        return unique.sorted { $0.digits.lexicographicallyPrecedes($1.digits) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(cage.clue(hidingOperation: hidesOperators))
                        .font(.title2.weight(.semibold))
                    Text("All possible combinations that satisfy the arithmetic. Tap a row to set those numbers as notes. Notes already in this group are removed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        if visible.isEmpty {
                            Text(possible.isEmpty
                                 ? "No combinations fit the numbers on the board."
                                 : "You removed every combination that still fits.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(Array(visible.enumerated()), id: \.offset) { index, combo in
                                if index > 0 {
                                    Divider()
                                }
                                combinationRow(combo)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))

                    if !dismissed.isEmpty {
                        Button(action: onReset) {
                            Text("Reset combinations")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(MathdokuGlassButtonStyle(glass: .regular.interactive(), cornerRadius: 16))
                        .accessibilityHint("Puts removed combinations back.")
                    }
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background { MathdokuBackground() }
            .navigationTitle("Cell group")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .mathdokuScreen()
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private func combinationRow(_ combo: CageCombo) -> some View {
        HStack(spacing: 8) {
            Button {
                let matches = visiblePositional.filter { $0.canonical == combo.canonical }
                onSetNotes(matches)
            } label: {
                HStack(spacing: 6) {
                    ForEach(Array(combo.digits.enumerated()), id: \.offset) { _, digit in
                        Text("\(digit)")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(MathdokuHitButtonStyle())
            .accessibilityLabel(combo.digits.map(String.init).joined(separator: ", "))
            .accessibilityHint("Sets these numbers as notes and removes notes already in this group.")

            Button {
                onRemove(combo)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.title3)
            }
            .buttonStyle(MathdokuHitButtonStyle())
            .accessibilityLabel("Remove combination")
        }
        .padding(.vertical, 12)
    }
}

private struct MathdokuBoard: View {
    let puzzle: Puzzle
    let entries: [[Int?]]
    let notes: [[Set<Int>]]
    let selection: CellIndex?
    let analysis: BoardAnalysis
    let highlight: MistakeHighlight
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
        .buttonStyle(MathdokuHitButtonStyle())
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
        highlight.marks(cell, entries: entries, puzzle: puzzle, analysis: analysis)
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
            parts.append("cell group \(clue)")
        }
        if isConflict(cell) {
            parts.append("needs attention")
        }
        return parts.joined(separator: ", ")
    }
}

private struct PlayKeyboardModifier: ViewModifier {
    var size: Int
    var onNumber: (Int) -> Void
    var onErase: () -> Void
    var onNudge: (Int, Int) -> Void

    func body(content: Content) -> some View {
        #if os(iOS) || os(macOS) || os(visionOS)
        content
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(characters: .decimalDigits) { press in
                guard let number = press.characters.first?.wholeNumberValue,
                      (1...size).contains(number) else { return .ignored }
                onNumber(number)
                return .handled
            }
            .onKeyPress(.delete) {
                onErase()
                return .handled
            }
            .onKeyPress(.leftArrow) { onNudge(0, -1); return .handled }
            .onKeyPress(.rightArrow) { onNudge(0, 1); return .handled }
            .onKeyPress(.upArrow) { onNudge(-1, 0); return .handled }
            .onKeyPress(.downArrow) { onNudge(1, 0); return .handled }
        #else
        content
        #endif
    }
}

#Preview {
    NavigationStack {
        GamePlayView(launch: GameLaunch(size: 4, difficulty: .easy, seed: 1, isDaily: false, id: 1))
            .mathdokuScreen()
    }
    .mathdokuScreen()
    .environment(PlayerStats.preview)
    .environment(ActiveGame.preview)
    .environment(GameDeck.preview)
}
