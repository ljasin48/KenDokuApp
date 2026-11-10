# Mathdoku

Mathdoku is an arithmetic Sudoku in the [KenKen](https://en.wikipedia.org/wiki/KenKen) style. Puzzles are generated on the device. Progress and statistics stay on the device.

## How to play

- Every row and every column holds 1 through the grid size exactly once. There are no Sudoku boxes.
- Heavy outlines mark each cell group. The corner label is a target and an operation: add, subtract, multiply, or divide.
- The numbers in a cell group must combine with that operation to hit the target. A group of one cell is already filled with its number.
- Subtraction and division may use the cells in any order, as long as some order produces the target.
- No-op mode hides the operation symbol. The puzzle is the same; only the symbol is missing.

## Play

- Start a game from 3×3 through 9×9, at Easy, Medium, or Hard.
- Play the daily puzzle, a shared 6×6 Medium board. Solving it on consecutive days builds a streak.
- Resume an unfinished game. Starting a different puzzle asks before replacing the saved one.
- Enter numbers, make notes, undo, erase, and take a hint. A hint keeps the solve from counting as a best time.
- Choose which operations appear in new games. Division cannot be the only operation. The daily puzzle uses the standard set.
- Highlight mistakes for a finished cell group that misses its target, or for any cell that does not match the solution.
- Switch themes: Mathdoku, Space, Daylight, and Grove. A theme changes the colors and the app icon.
- Statistics track puzzles solved, the daily streak, and best times for each size and difficulty.

## Requirements

- Xcode 27 or later
- Deployment target 26.5 on every platform
- iPhone, iPad, Mac, Apple TV, and visionOS

Open `Mathdoku.xcodeproj` and run the **Mathdoku** scheme. The bundle identifier is `com.loganjasin.Mathdoku`.

## Project layout

| Path | What it does |
| --- | --- |
| `Mathdoku/MathdokuApp.swift` | App entry and scene setup |
| `Mathdoku/ContentView.swift` | Navigation, theme, and the next board |
| `Mathdoku/LandingView.swift` | Home screen, new game, resume, and daily puzzle |
| `Mathdoku/HomeDestinationView.swift` | Game, statistics, settings, and how to play |
| `Mathdoku/GamePlayView.swift` | Board, entry, notes, and the solved state |
| `Mathdoku/GameSetupView.swift` | Saved settings, a game launch, and the operations editor |
| `Mathdoku/GameExtrasView.swift` | Statistics and settings |
| `Mathdoku/Puzzle.swift` | Puzzle model, rules, and board checking |
| `Mathdoku/MathdokuGenerator.swift` | On-device puzzle generation |
| `Mathdoku/GameDeck.swift` | One prepared puzzle for the next new game |
| `Mathdoku/ActiveGame.swift` | Saved game |
| `Mathdoku/PlayerStats.swift` | Solved counts, streaks, and best times |
| `Mathdoku/AppTheme.swift` | Theme colors and icons |
