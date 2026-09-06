//
//  NetworkCounter.swift
//  70K Bands
//
//  Filter console with: NETWORK_COUNTER
//

import Foundation

enum NetworkCounter {
    private static let lock = NSLock()
    private static var counts: [String: Int] = [:]

    static func record(_ name: String) {
        lock.lock()
        counts[name, default: 0] += 1
        let n = counts[name] ?? 0
        lock.unlock()
        print("NETWORK_COUNTER count=\(n) \(name)")
    }

    static func recordDropbox(_ urlString: String) {
        record("url=\(normalizeUrl(urlString))")
    }

    private static func normalizeUrl(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var comps = URLComponents(string: trimmed) else { return trimmed }
        comps.queryItems = comps.queryItems?.filter {
            let name = $0.name.lowercased()
            return name != "_t" && name != "t" && name != "cachebust"
        }
        if comps.queryItems?.isEmpty == true {
            comps.queryItems = nil
        }
        return comps.string ?? trimmed
    }
}
