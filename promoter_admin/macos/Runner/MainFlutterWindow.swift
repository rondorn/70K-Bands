import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let frameAutosaveName = NSWindow.FrameAutosaveName("MainFlutterWindow")

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    self.minSize = NSSize(width: 720, height: 560)
    self.title = "Open Metal Fest Admin"

    // Restore the OS-saved frame when present. On a true first launch (no
    // saved frame), fill the screen's usable area — not fullscreen (menu bar
    // and Dock stay visible via NSScreen.visibleFrame).
    if !self.setFrameUsingName(Self.frameAutosaveName) {
      let screen = self.screen ?? NSScreen.main
      if let visible = screen?.visibleFrame {
        self.setFrame(visible, display: true)
      }
    }
    self.setFrameAutosaveName(Self.frameAutosaveName)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerDesktopUpdateChannel(flutterViewController)

    super.awakeFromNib()
  }
}

private func registerDesktopUpdateChannel(_ controller: FlutterViewController) {
  let channel = FlutterMethodChannel(
    name: "com.rdorn.open-metal-fest-admin/desktop_update",
    binaryMessenger: controller.engine.binaryMessenger
  )
  channel.setMethodCallHandler { call, result in
    guard call.method == "launchInstaller" else {
      result(FlutterMethodNotImplemented)
      return
    }
    launchInstaller(call.arguments as? String, result: result)
  }
}

private func launchInstaller(_ scriptPath: String?, result: @escaping FlutterResult) {
  guard let scriptPath, !scriptPath.isEmpty else {
    result(
      FlutterError(code: "bad_args", message: "Expected a script path", details: nil)
    )
    return
  }
  let helper = Bundle.main.bundleURL
    .appendingPathComponent("Contents/Helpers/UpdateInstaller.app")
  guard FileManager.default.fileExists(atPath: helper.path) else {
    result(
      FlutterError(
        code: "missing_helper",
        message: "This copy of the app cannot finish the update. Install the latest version by hand.",
        details: nil
      )
    )
    return
  }
  let config = NSWorkspace.OpenConfiguration()
  config.createsNewApplicationInstance = true
  config.arguments = [scriptPath]
  NSWorkspace.shared.openApplication(at: helper, configuration: config) { _, error in
    DispatchQueue.main.async {
      if let error {
        result(
          FlutterError(
            code: "launch_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      } else {
        result(nil)
      }
    }
  }
}


