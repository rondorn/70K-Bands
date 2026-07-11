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

    super.awakeFromNib()
  }
}
