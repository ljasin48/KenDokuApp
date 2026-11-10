//
//  HomeDestinationView.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/7/26.
//

import SwiftUI

struct HomeDestinationView: View {
    let route: HomeRoute

    var body: some View {
        Group {
            switch route {
            case .newGame(let launch):
                GamePlayView(launch: launch)
            case .dailyPuzzle:
                GamePlayView(launch: .daily())
            case .statistics:
                StatisticsView()
            case .settings:
                SettingsView()
            case .howToPlay:
                howToPlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { MathdokuBackground() }
        .navigationTitle(route.title)
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var howToPlay: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                rule(
                    title: "Sudoku grid",
                    text: "Every row and every column holds 1 through the grid size exactly once."
                )
                rule(
                    title: "Read the cell groups",
                    text: "Heavy outlines mark each cell group containing a target and an operation: add, subtract, multiply, or divide."
                )
                rule(
                    title: "Make the math work",
                    text: "The numbers in a cell group must combine with that operation to hit the target. For example, a two-cell group with a target of 12 and a multiply operation could either be (2, 6) or (3, 4)."
                )
                rule(
                    title: "Order is free",
                    text: "Subtraction and division may use the cells in any order, as long as some order produces the target."
                )
                rule(
                    title: "No-op mode",
                    text: "Settings can hide the operation symbol. The puzzle is the same; only the symbol is missing."
                )
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func rule(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

#Preview {
    NavigationStack {
        HomeDestinationView(route: .howToPlay)
            .mathdokuScreen()
    }
    .mathdokuScreen()
    .environment(PlayerStats.preview)
    .environment(ActiveGame.preview)
}
