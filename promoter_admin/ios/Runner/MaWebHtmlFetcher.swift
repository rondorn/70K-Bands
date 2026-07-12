import Flutter
import UIKit
import WebKit

/// Fetches Metal Archives HTML via WKWebView so Cloudflare JS challenges can complete.
enum MaWebHtmlFetcher {
  private static var active: Fetcher?

  static func fetch(url: URL, result: @escaping FlutterResult) {
    // Cancel any in-flight fetch.
    active?.cancel()
    let fetcher = Fetcher(url: url) { html, error in
      active = nil
      if let error = error {
        result(
          FlutterError(
            code: "ma_webview_fetch_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }
      result(html)
    }
    active = fetcher
    fetcher.start()
  }
}

private final class Fetcher: NSObject, WKNavigationDelegate {
  private let url: URL
  private let completion: (String?, Error?) -> Void
  private var webView: WKWebView?
  private var hostView: UIView?
  private var pollTimer: Timer?
  private var timeoutTimer: Timer?
  private var finished = false
  private let timeoutSeconds: TimeInterval = 35
  private let pollInterval: TimeInterval = 0.75

  /// Safari UA so Cloudflare's browser challenge can run; not the curl allowlist UA.
  private let safariUA =
    "Mozilla/5.0 (iPad; CPU OS 18_5 like Mac OS X) AppleWebKit/605.1.15 "
    + "(KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"

  init(url: URL, completion: @escaping (String?, Error?) -> Void) {
    self.url = url
    self.completion = completion
  }

  func start() {
    DispatchQueue.main.async {
      guard let window = Self.keyWindow() else {
        self.finish(html: nil, error: Self.error("No UI window available for WebKit fetch."))
        return
      }

      let config = WKWebViewConfiguration()
      config.websiteDataStore = .nonPersistent()
      config.defaultWebpagePreferences.allowsContentJavaScript = true

      let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
      webView.isHidden = true
      webView.navigationDelegate = self
      webView.customUserAgent = self.safariUA
      // Must be in the hierarchy or Cloudflare JS often never completes.
      window.addSubview(webView)
      self.webView = webView
      self.hostView = webView

      var request = URLRequest(url: self.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
      request.setValue(self.safariUA, forHTTPHeaderField: "User-Agent")
      request.setValue(
        "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        forHTTPHeaderField: "Accept"
      )
      webView.load(request)

      self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: self.timeoutSeconds, repeats: false) { [weak self] _ in
        self?.finish(html: nil, error: Self.error("Timed out waiting for Metal Archives page."))
      }
    }
  }

  func cancel() {
    finish(html: nil, error: Self.error("Cancelled."))
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    startPolling()
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    finish(html: nil, error: error)
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    finish(html: nil, error: error)
  }

  private func startPolling() {
    pollTimer?.invalidate()
    pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
      self?.evaluateHtml()
    }
    evaluateHtml()
  }

  private func evaluateHtml() {
    guard let webView = webView, !finished else { return }
    webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] value, error in
      guard let self = self, !self.finished else { return }
      if let error = error {
        // Keep polling through transient evaluate errors during challenge.
        NSLog("MaWebHtmlFetcher evaluate error: %@", error.localizedDescription)
        return
      }
      guard let html = value as? String, html.count >= 500 else { return }
      let lower = html.lowercased()
      let looksLikeMa =
        lower.contains("class=\"band_name\"")
        || lower.contains("var bandname =")
        || lower.contains("id=\"band_stats\"")
        || lower.contains("class=\"display discog\"")
      if looksLikeMa {
        self.finish(html: html, error: nil)
        return
      }
      // Successful MA pages embed Cloudflare jsd scripts; ignore those.
      let challenge =
        lower.contains("just a moment...")
        || lower.contains("<title>just a moment")
        || lower.contains("cf-browser-verification")
        || lower.contains("cdn-cgi/challenge-platform/h/")
        || lower.contains("checking your browser")
      if challenge {
        NSLog("MaWebHtmlFetcher still on challenge (%d bytes)", html.count)
        return
      }
      if html.count < 5000 {
        return
      }
      self.finish(html: html, error: nil)
    }
  }

  private func finish(html: String?, error: Error?) {
    guard !finished else { return }
    finished = true
    pollTimer?.invalidate()
    pollTimer = nil
    timeoutTimer?.invalidate()
    timeoutTimer = nil
    DispatchQueue.main.async {
      self.webView?.stopLoading()
      self.webView?.navigationDelegate = nil
      self.hostView?.removeFromSuperview()
      self.webView = nil
      self.hostView = nil
      self.completion(html, error)
    }
  }

  private static func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }
      ?? UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first
  }

  private static func error(_ message: String) -> NSError {
    NSError(domain: "MaWebHtmlFetcher", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}
