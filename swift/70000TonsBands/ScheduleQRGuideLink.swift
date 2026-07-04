//
//  ScheduleQRGuideLink.swift
//  70K Bands
//
//  Guide QR deep link: system Camera app opens this app to the schedule QR scanner.
//  URL string comes from festival.json scheduleQRGuideURL (e.g. bands70k://schedule-scan).
//

import Foundation

enum ScheduleQRGuideLink {

    static let openScannerNotification = Notification.Name("OpenScheduleQRScannerFromGuide")

    private static var pendingOpenScanner = false

    /// Configured guide URL when schedule QR share is enabled; nil otherwise.
    static var configuredGuideURLString: String? {
        guard FestivalConfig.current.scheduleQRShareEnabled else { return nil }
        let trimmed = FestivalConfig.current.scheduleQRGuideURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func handleIncomingURL(_ url: URL) -> Bool {
        guard matchesGuideURL(url) else { return false }
        print("[QRGuide] Incoming guide URL: \(url.absoluteString)")
        pendingOpenScanner = true
        DispatchQueue.main.async {
            deliverPendingOpenScannerIfNeeded()
        }
        return true
    }

    /// Call when main UI (masterView) is ready — delivers a guide URL received at cold launch.
    static func deliverPendingOpenScannerIfNeeded() {
        guard pendingOpenScanner else { return }
        guard masterView != nil else { return }
        pendingOpenScanner = false
        NotificationCenter.default.post(name: openScannerNotification, object: nil)
    }

    static func matchesGuideURL(_ url: URL) -> Bool {
        guard let expected = configuredGuideURLString, let expectedURL = URL(string: expected) else { return false }
        return urlsEquivalent(url, expectedURL)
    }

    static func matchesGuidePayload(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return false }
        return matchesGuideURLString(text)
    }

    /// Scanner only: guide QR is a short UTF-8 URL string, not a truncated binary schedule payload.
    static func matchesGuidePayloadExact(_ data: Data) -> Bool {
        guard let expected = configuredGuideURLString else { return false }
        let trimmedExpected = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExpected.isEmpty else { return false }
        // Binary schedule QRs start with type 0/1/2 and are much larger when complete.
        if let first = data.first, first <= 2 { return false }
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              text == trimmedExpected else { return false }
        return data.count <= trimmedExpected.utf8.count + 4
    }

    static func matchesGuideURLString(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return matchesGuideURL(url)
    }

    private static func urlsEquivalent(_ a: URL, _ b: URL) -> Bool {
        let schemeA = (a.scheme ?? "").lowercased()
        let schemeB = (b.scheme ?? "").lowercased()
        guard schemeA == schemeB else { return false }
        let hostA = (a.host ?? "").lowercased()
        let hostB = (b.host ?? "").lowercased()
        if !hostA.isEmpty || !hostB.isEmpty, hostA != hostB { return false }
        let pathA = normalizedPath(a.path)
        let pathB = normalizedPath(b.path)
        return pathA == pathB
    }

    private static func normalizedPath(_ path: String) -> String {
        var p = path
        if !p.hasPrefix("/") { p = "/" + p }
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        return p.lowercased()
    }
}
