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
    guard call.method == "revealFolder" else {
      result(FlutterMethodNotImplemented)
      return
    }
    revealFolder(call.arguments as? String, result: result)
  }
}

private func revealFolder(_ path: String?, result: @escaping FlutterResult) {
  guard let path, !path.isEmpty else {
    result(
      FlutterError(code: "bad_args", message: "Expected a folder path", details: nil)
    )
    return
  }
  let opened = NSWorkspace.shared.open(URL(fileURLWithPath: path))
  if opened {
    result(nil)
  } else {
    result(
      FlutterError(
        code: "reveal_failed",
        message: "Could not open the update in Finder.",
        details: nil
      )
    )
  }
}


