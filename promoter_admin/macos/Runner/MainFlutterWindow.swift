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
    switch call.method {
    case "launchApp":
      launchUpdatedApp(call.arguments as? String, result: result)
    case "runPrivilegedShell":
      runPrivilegedShell(call.arguments as? String, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private func launchUpdatedApp(_ path: String?, result: @escaping FlutterResult) {
  guard let path, !path.isEmpty else {
    result(
      FlutterError(code: "bad_args", message: "Expected an app path", details: nil)
    )
    return
  }
  let url = URL(fileURLWithPath: path)
  let config = NSWorkspace.OpenConfiguration()
  config.createsNewApplicationInstance = true
  NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
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

/// Runs the installer outside the app sandbox. A sandboxed ditto can create a
/// file in /Applications and still be denied when copying the app bundle.
private func runPrivilegedShell(_ scriptPath: String?, result: @escaping FlutterResult) {
  guard let scriptPath, !scriptPath.isEmpty else {
    result(
      FlutterError(code: "bad_args", message: "Expected a script path", details: nil)
    )
    return
  }
  let shellPath = "'" + scriptPath.replacingOccurrences(of: "'", with: "'\\''") + "'"
  let command = "/bin/bash \(shellPath)"
  let prompt = "Open Metal Fest Admin needs an administrator password to install the update."
  let source =
    "do shell script \(appleScriptString(command)) with prompt \(appleScriptString(prompt)) with administrator privileges"
  var errorInfo: NSDictionary?
  _ = NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
  if let errorInfo {
    let number = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
    let message = (errorInfo[NSAppleScript.errorMessage] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if number == -128 {
      result(
        FlutterError(
          code: "cancelled",
          message: "The update was not installed.",
          details: nil
        )
      )
      return
    }
    result(
      FlutterError(
        code: "install_failed",
        message: (message?.isEmpty == false) ? message : "The update was not installed.",
        details: nil
      )
    )
    return
  }
  result(nil)
}

private func appleScriptString(_ value: String) -> String {
  let escaped = value
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
  return "\"\(escaped)\""
}
