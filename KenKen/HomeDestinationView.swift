//
//  HomeDestinationView.swift
//  KenKen
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
        .background { KenDokuBackground() }
        .navigationTitle(route.title)
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var howToPlay: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                rule(
                    title: "One of each number",
                    text: "Every row and every column holds 1 through the grid size exactly once. There are no Sudoku boxes."
                )
                rule(
                    title: "Read the cages",
                    text: "Heavy outlines group cells into cages. The corner label is a target and an operation: add, subtract, multiply, or divide."
                )
                rule(
                    title: "Make the math work",
                    text: "The numbers in a cage must combine with that operation to hit the target. A label with no operation is a single cell fixed to that number."
                )
                rule(
                    title: "Order is free",
                    text: "Subtraction and division may use the cells in any order, as long as some order produces the target."
                )
                rule(
                    title: "No-op mode",
                    text: "Settings can hide the operation. The target still has to be reachable by one of the operations you left on."
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
            .kendokuScreen()
    }
    .kendokuScreen()
}
