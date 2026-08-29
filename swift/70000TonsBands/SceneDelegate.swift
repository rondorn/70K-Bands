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

        for context in connectionOptions.urlContexts {
            _ = appDelegate.handleIncomingOpenURL(context.url, delay: 1.0)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        for context in URLContexts {
            _ = appDelegate.handleIncomingOpenURL(context.url)
        }
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
