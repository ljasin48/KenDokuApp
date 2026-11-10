//
//  AppTheme.swift
//  Mathdoku
//
//  Created by Logan Jasin on 11/8/26.
//

import SwiftUI
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case mathdoku
    case space
    case daylight
    case grove

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mathdoku: "Mathdoku"
        case .space: "Space"
        case .daylight: "Daylight"
        case .grove: "Grove"
        }
    }

    var detail: String {
        switch self {
        case .mathdoku: "Ink, moss, and clay"
        case .space: "Night sky and starlight"
        case .daylight: "Warm paper and terracotta"
        case .grove: "Forest and gold"
        }
    }

    var accent: Color {
        switch self {
        case .mathdoku:
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
        case .mathdoku:
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
                Color(red: 0.16, green: 0.09, blue: 0.06),
                Color(red: 0.36, green: 0.18, blue: 0.12),
                Color(red: 0.48, green: 0.26, blue: 0.16)
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
        case .mathdoku:
            Color.white.opacity(0.05)
        case .space, .daylight, .grove:
            Color.white.opacity(0.06)
        }
    }

    var paper: Color {
        switch self {
        case .mathdoku:
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
        case .mathdoku:
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
        case .mathdoku:
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

    /// Alternate app icon set. `nil` restores the primary Mathdoku icon.
    var alternateIconName: String? {
        switch self {
        case .mathdoku: nil
        case .space: "AppIcon-Space"
        case .daylight: "AppIcon-Daylight"
        case .grove: "AppIcon-Grove"
        }
    }

    var iconAssetName: String {
        switch self {
        case .mathdoku: "ThemeIconMathdoku"
        case .space: "ThemeIconSpace"
        case .daylight: "ThemeIconDaylight"
        case .grove: "ThemeIconGrove"
        }
    }

    /// Keeps the Home Screen or Dock icon aligned with the selected theme.
    func applyIcon() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }
        #endif

        let requestKey = alternateIconName ?? ""
        guard AppIconRequest.claim(requestKey) else { return }

        #if os(iOS) || os(tvOS)
        let application = UIApplication.shared
        guard application.supportsAlternateIcons else {
            AppIconRequest.release(requestKey)
            return
        }
        let iconName = alternateIconName
        guard application.alternateIconName != iconName else { return }
        application.setAlternateIconName(iconName) { error in
            guard error != nil else { return }
            Task { @MainActor in
                AppIconRequest.release(requestKey)
            }
        }
        #elseif os(macOS)
        guard let image = NSImage(named: iconAssetName) else {
            AppIconRequest.release(requestKey)
            return
        }
        NSApplication.shared.applicationIconImage = image
        #endif
    }
}

/// Collapses repeated theme updates so the system icon alert is not shown twice.
private enum AppIconRequest {
    private static var claimedKey: String?

    static func claim(_ key: String) -> Bool {
        guard claimedKey != key else { return false }
        claimedKey = key
        return true
    }

    static func release(_ key: String) {
        guard claimedKey == key else { return }
        claimedKey = nil
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.mathdoku
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
