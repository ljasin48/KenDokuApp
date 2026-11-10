//
//  KenDokuApp.swift
//  KenDoku
//
//  Created by Logan Jasin on 9/1/26.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

@main
struct KenDokuApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(KenDokuAppDelegate.self) private var appDelegate
    #endif
    @State private var stats = PlayerStats()
    @State private var activeGame = ActiveGame()
    @State private var gameDeck = GameDeck()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(stats)
                .environment(activeGame)
                .environment(gameDeck)
                #if os(iOS)
                .background { ClosedDuoOrientationLock() }
                #endif
        }
    }
}

#if os(iOS)
/// Portrait only for a scene whose hinge is closed (the outer screen). The inner screen keeps the normal mask.
enum ClosedDuoOrientation {
    private static var closedSceneIDs = Set<ObjectIdentifier>()

    static func mask(for scene: UIWindowScene) -> UIInterfaceOrientationMask {
        closedSceneIDs.contains(ObjectIdentifier(scene)) ? .portrait : unlockedMask(for: scene)
    }

    static func update(scene: UIWindowScene, closed: Bool) {
        let identifier = ObjectIdentifier(scene)
        let wasClosed = closedSceneIDs.contains(identifier)
        if closed {
            closedSceneIDs.insert(identifier)
        } else {
            closedSceneIDs.remove(identifier)
        }
        guard wasClosed != closed else { return }
        let orientations = mask(for: scene)
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
    }

    private static func unlockedMask(for scene: UIWindowScene) -> UIInterfaceOrientationMask {
        scene.traitCollection.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}

final class KenDokuAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = KenDokuSceneDelegate.self
        }
        return configuration
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        guard let scene = window?.windowScene else { return .allButUpsideDown }
        return ClosedDuoOrientation.mask(for: scene)
    }
}

final class KenDokuSceneDelegate: NSObject, UIWindowSceneDelegate {
    func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask {
        ClosedDuoOrientation.mask(for: windowScene)
    }
}

private struct ClosedDuoOrientationLock: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        HingeLockView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class HingeLockView: UIView {
    private var closed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        if #available(iOS 27.1, *) {
            let interaction = UIHingeInteraction { [weak self] _, update in
                self?.closed = update.hinge?.status == .closed
                self?.apply()
            }
            addInteraction(interaction)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        apply()
    }

    private func apply() {
        guard let scene = window?.windowScene else { return }
        ClosedDuoOrientation.update(scene: scene, closed: closed)
    }
}
#endif
