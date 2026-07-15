import Flutter
import UIKit
import WebKit

/// Fetches Metal Archives HTML/JSON via WKWebView so Cloudflare JS challenges can complete.
///
/// Reuses one WKWebView and the default cookie store so the CF challenge is paid once per
/// app session; later Discover fetches (search → band → discog → links) stay fast.
enum MaWebHtmlFetcher {
  private static var session: Session?

  static func fetch(url: URL, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let session = Self.session ?? Session()
      Self.session = session
      session.fetch(url: url) { html, error in
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
    }
  }
}

private final class Session: NSObject, WKNavigationDelegate {
  private var webView: WKWebView?
  private var hostView: UIView?
  private var pollTimer: Timer?
  private var timeoutTimer: Timer?
  private var finished = false
  private var completion: ((String?, Error?) -> Void)?
  private var requestURL: URL?
  private var challengeCleared = false

  /// First hit needs CF time; warm hits after cookies exist are much faster.
  private var coldTimeout: TimeInterval { 28 }
  private var warmTimeout: TimeInterval { 12 }
  private let pollInterval: TimeInterval = 0.4

  /// Safari UA so Cloudflare's browser challenge can run; not the curl allowlist UA.
  private let safariUA =
    "Mozilla/5.0 (iPad; CPU OS 18_5 like Mac OS X) AppleWebKit/605.1.15 "
    + "(KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"

  func fetch(url: URL, completion: @escaping (String?, Error?) -> Void) {
    // Cancel any in-flight fetch (serial by design).
    if self.completion != nil {
      finish(html: nil, error: Self.error("Cancelled."), destroyWebView: false)
    }
    finished = false
    self.completion = completion
    requestURL = url

    guard let window = Self.keyWindow() else {
      finish(html: nil, error: Self.error("No UI window available for WebKit fetch."))
      return
    }

    let webView = ensureWebView(in: window)
    var request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 25
    )
    request.setValue(safariUA, forHTTPHeaderField: "User-Agent")
    request.setValue(
      "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      forHTTPHeaderField: "Accept"
    )
    webView.load(request)

    let timeout = challengeCleared ? warmTimeout : coldTimeout
    timeoutTimer?.invalidate()
    timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
      self?.finish(
        html: nil,
        error: Self.error("Timed out waiting for Metal Archives page."),
        destroyWebView: false
      )
    }
  }

  private func ensureWebView(in window: UIWindow) -> WKWebView {
    if let webView = webView {
      return webView
    }
    let config = WKWebViewConfiguration()
    // Keep cookies so Cloudflare isn't re-solved on every Discover sub-request.
    config.websiteDataStore = .default()
    config.defaultWebpagePreferences.allowsContentJavaScript = true

    let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
    webView.isHidden = true
    webView.navigationDelegate = self
    webView.customUserAgent = safariUA
    // Must be in the hierarchy or Cloudflare JS often never completes.
    window.addSubview(webView)
    self.webView = webView
    self.hostView = webView
    return webView
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    startPolling()
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    finish(html: nil, error: error, destroyWebView: false)
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    finish(html: nil, error: error, destroyWebView: false)
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
    // Prefer body text for JSON ajax endpoints; fall back to outerHTML for band pages.
    let js = """
    (function() {
      var text = (document.body && (document.body.innerText || document.body.textContent)) || '';
      var trimmed = text.trim();
      if (trimmed.charAt(0) === '{' || trimmed.charAt(0) === '[') {
        return trimmed;
      }
      return document.documentElement.outerHTML;
    })()
    """
    webView.evaluateJavaScript(js) { [weak self] value, error in
      guard let self = self, !self.finished else { return }
      if let error = error {
        NSLog("MaWebHtmlFetcher evaluate error: %@", error.localizedDescription)
        return
      }
      guard let html = value as? String, html.count >= 20 else { return }
      if Self.isAcceptableBody(html) {
        self.challengeCleared = true
        self.finish(html: html, error: nil, destroyWebView: false)
        return
      }
      if Self.isChallenge(html) {
        NSLog("MaWebHtmlFetcher still on challenge (%d bytes)", html.count)
        return
      }
    }
  }

  private func finish(html: String?, error: Error?, destroyWebView: Bool = false) {
    guard !finished else { return }
    finished = true
    pollTimer?.invalidate()
    pollTimer = nil
    timeoutTimer?.invalidate()
    timeoutTimer = nil
    let cb = completion
    completion = nil
    requestURL = nil
    webView?.stopLoading()
    if destroyWebView {
      webView?.navigationDelegate = nil
      hostView?.removeFromSuperview()
      webView = nil
      hostView = nil
    }
    cb?(html, error)
  }

  private static func isAcceptableBody(_ body: String) -> Bool {
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
      return trimmed.count >= 2
    }
    let lower = body.lowercased()
    if isChallenge(body) { return false }
    if lower.contains("class=\"band_name\"")
      || lower.contains("var bandname =")
      || lower.contains("id=\"band_stats\"")
      || lower.contains("class=\"display discog\"")
      || lower.contains("id=\"band_disco\"")
      || lower.contains("header_official")
      || lower.contains("id=\"logo\"") {
      return true
    }
    if lower.contains("<table") || lower.contains("<tr") {
      return body.count >= 200
    }
    return body.count >= 500
  }

  private static func isChallenge(_ body: String) -> Bool {
    let lower = body.lowercased()
    if lower.contains("class=\"band_name\"")
      || lower.contains("var bandname =")
      || lower.contains("id=\"band_stats\"")
      || lower.contains("class=\"display discog\"")
      || lower.contains("header_official") {
      return false
    }
    return lower.contains("just a moment...")
      || lower.contains("<title>just a moment")
      || lower.contains("cf-browser-verification")
      || lower.contains("checking your browser")
      || lower.contains("cdn-cgi/challenge-platform/h/")
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
