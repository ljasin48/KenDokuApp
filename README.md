# KenDoku

KenDoku is a [KenKen](https://en.wikipedia.org/wiki/KenKen)-style number puzzle. Puzzles are generated on the device. Progress and statistics stay on the device.

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
- Switch themes: KenDoku, Space, Daylight, and Grove. A theme changes the colors and the app icon.
- Statistics track puzzles solved, the daily streak, and best times for each size and difficulty.

## Requirements

- Xcode 27 or later
- Deployment target 26.5 on every platform

Open `KenDoku.xcodeproj` and run the **KenDoku** scheme. The bundle identifier is `com.loganjasin.KenDoku`.

## Project layout

| Path | What it does |
| --- | --- |
| `KenDoku/KenDokuApp.swift` | App entry and scene setup |
| `KenDoku/LandingView.swift` | Home screen, new game, resume, and daily puzzle |
| `KenDoku/GamePlayView.swift` | Board, entry, notes, and the solved state |
| `KenDoku/GameExtrasView.swift` | Statistics and settings |
| `KenDoku/Puzzle.swift` | Puzzle model, rules, and board checking |
| `KenDoku/KenKenGenerator.swift` | On-device puzzle generation |
| `KenDoku/ActiveGame.swift` | Saved game |
| `KenDoku/PlayerStats.swift` | Solved counts, streaks, and best times |
| `KenDoku/AppTheme.swift` | Theme colors and icons |
