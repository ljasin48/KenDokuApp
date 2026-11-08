//
//  AppTheme.swift
//  KenKen
//
//  Created by Logan Jasin on 11/8/26.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case kendoku
    case space
    case daylight
    case grove

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kendoku: "KenDoku"
        case .space: "Space"
        case .daylight: "Daylight"
        case .grove: "Grove"
        }
    }

    var detail: String {
        switch self {
        case .kendoku: "Ink, moss, and clay"
        case .space: "Night sky and starlight"
        case .daylight: "Warm paper and terracotta"
        case .grove: "Forest and gold"
        }
    }

    var colorScheme: ColorScheme {
        self == .daylight ? .light : .dark
    }

    var accent: Color {
        switch self {
        case .kendoku:
            Color(red: 0.93, green: 0.45, blue: 0.27)
        case .space:
            Color(red: 0.45, green: 0.86, blue: 0.98)
        case .daylight:
            Color(red: 0.76, green: 0.34, blue: 0.22)
        case .grove:
            Color(red: 0.90, green: 0.72, blue: 0.32)
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .kendoku:
            [
                Color(red: 0.07, green: 0.11, blue: 0.15),
                Color(red: 0.18, green: 0.34, blue: 0.32),
                Color(red: 0.32, green: 0.16, blue: 0.12)
            ]
        case .space:
            [
                Color(red: 0.03, green: 0.04, blue: 0.10),
                Color(red: 0.10, green: 0.08, blue: 0.28),
                Color(red: 0.22, green: 0.07, blue: 0.32)
            ]
        case .daylight:
            [
                Color(red: 0.98, green: 0.95, blue: 0.88),
                Color(red: 0.93, green: 0.80, blue: 0.64),
                Color(red: 0.86, green: 0.60, blue: 0.44)
            ]
        case .grove:
            [
                Color(red: 0.04, green: 0.11, blue: 0.08),
                Color(red: 0.10, green: 0.28, blue: 0.18),
                Color(red: 0.18, green: 0.22, blue: 0.08)
            ]
        }
    }

    var gridLine: Color {
        switch self {
        case .kendoku:
            Color.white.opacity(0.05)
        case .space, .grove:
            Color.white.opacity(0.06)
        case .daylight:
            Color.black.opacity(0.06)
        }
    }

    var paper: Color {
        switch self {
        case .kendoku:
            Color(red: 0.97, green: 0.94, blue: 0.89)
        case .space:
            Color(red: 0.93, green: 0.94, blue: 0.97)
        case .daylight:
            Color(red: 0.99, green: 0.97, blue: 0.93)
        case .grove:
            Color(red: 0.95, green: 0.94, blue: 0.86)
        }
    }

    var boardLine: Color {
        switch self {
        case .kendoku:
            Color(red: 0.11, green: 0.12, blue: 0.14)
        case .space:
            Color(red: 0.07, green: 0.09, blue: 0.16)
        case .daylight:
            Color(red: 0.22, green: 0.16, blue: 0.12)
        case .grove:
            Color(red: 0.12, green: 0.16, blue: 0.11)
        }
    }

    var clue: Color {
        switch self {
        case .kendoku:
            Color(red: 0.55, green: 0.24, blue: 0.16)
        case .space:
            Color(red: 0.20, green: 0.32, blue: 0.62)
        case .daylight:
            Color(red: 0.62, green: 0.28, blue: 0.18)
        case .grove:
            Color(red: 0.36, green: 0.40, blue: 0.12)
        }
    }

    var selectedFill: Color { accent.opacity(0.34) }

    var peerFill: Color { accent.opacity(0.12) }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.kendoku
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
