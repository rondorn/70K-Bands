//
//  SceneDelegate.swift
//  70000TonsBands
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene,
              let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        appDelegate.configureMainWindow(for: windowScene)
        window = appDelegate.window
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        FirebaseSyncTrace.log("sceneWillEnterForeground", "checking foreground recovery")
        appDelegate.recoverDeferredBackgroundWorkOnForeground()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.startFirebaseSyncEarlyIfNeeded()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        FirebaseSyncTrace.log("sceneDidEnterBackground", "forwarding to AppDelegate")
        appDelegate.handleAppEnteringBackground(application: UIApplication.shared)
    }
}
