//
//  ScheduleQRCompression.swift
//  70K Bands
//
//  Schedule QR contract (we control both sides; no backward compatibility):
//
//  SOURCE: CSV with exactly 11 columns (header + data rows):
//    Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL,ImageDate
//  Example: artistsSchedule2026_test.csv. Dates MM/DD/YYYY or M/D/YYYY; Day "Day 1" or "1/26"; times 24h; Type from fixed list; URLs may be https://www.dropbox.com/...
//
//  ENCODE (host):
//  1. Preprocess: replace "https://www.dropbox.com/" with "!DB!"; strip trailing commas per line.
//  2. Split: header row + data rows. Chunk1 = header + first half of data rows. Chunk2 = second half only (no header).
//  3. Per chunk: output 8 columns (omit Description URL, ImageURL, ImageDate) so each QR stays small and scannable. Substitute Band→2-digit, Location→2-digit, Type→1-digit; shorten Date/Day/Time.
//  4. LZMA-compress chunk UTF-8; prepend 4-byte little-endian uncompressed size. That is the payload (raw binary).
//  5. Store raw binary in the QR (no Base64; smaller payload → less dense QR → more reliable scan). Three QRs: top, middle, bottom.
//
//  DECODE (client):
//  1. Read three QRs (scanner returns raw payload via Vision payloadData). Order by vertical position: top, middle, bottom.
//  2. Per payload: bytes 0..<4 = LE uncompressed size n; bytes 4..<end = LZMA. Decode LZMA → n bytes UTF-8 CSV. If first 4 bytes not valid size, try Base64-decode (fallback).
//  3. Expand codes (2-digit→band/venue, 1-digit→type, date/day/time). Postprocess: "!DB!"→full URL; pad to 11 columns; header row → full 11-col header.
//  4. If two payloads: csv1 + "\n" + csv2 → one CSV (one header, all rows). Import that.
//

import Foundation
import Compression

// MARK: - Canonical maps (same order on host and client)

/// Event type code order – must match on both sides. Index 0 = "1", etc. (single digit 1...6).
private let eventTypeOrder: [String] = [
    "Show",
    "Meet and Greet",
    "Unofficial Event",
    "Special Event",
    "Clinic",
    "Cruiser Organized"
]

/// Two-digit code for index (01, 02, ... 99). Index is 0-based.
private func twoDigitCode(for index: Int) -> String {
    let n = index + 1
    if n < 1 || n > 99 { return "" }
    return String(format: "%02d", n)
}

/// Parse two-digit code to 0-based index. Returns nil if not 01-99.
private func indexFromTwoDigitCode(_ code: String) -> Int? {
    guard code.count == 2, let n = Int(code), n >= 1, n <= 99 else { return nil }
    return n - 1
}

/// Single-digit code for event type (1...9). Index is 0-based. We have ≤6 types.
private func oneDigitCodeForType(index: Int) -> String {
    guard index >= 0, index < 9 else { return "" }
    return String(index + 1)
}

/// Parse single-digit event type to 0-based index. Returns nil if not 1-9.
private func indexFromOneDigitTypeCode(_ code: String) -> Int? {
    guard code.count == 1, let n = Int(code), n >= 1, n <= 9 else { return nil }
    return n - 1
}

// MARK: - Compression (Host)

/// Build band list in canonical order: sorted alphabetically by name.
private func canonicalBandNames(forYear year: Int) -> [String] {
    let bands = DataManager.shared.fetchBands(forYear: year)
    return bands.map { $0.bandName }.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
}

/// Build venue list in canonical order: FestivalConfig order.
private func canonicalVenueNames() -> [String] {
    return FestivalConfig.current.getAllVenueNames()
}

/// Build event type list (canonical order).
private func canonicalEventTypes() -> [String] {
    return eventTypeOrder
}

/// Substitute first column (Band): if band is in list, replace with 2-digit code; else leave as-is.
private func compressBandColumn(_ value: String, bandNames: [String]) -> String {
    guard let idx = bandNames.firstIndex(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
        return value
    }
    return twoDigitCode(for: idx)
}

/// Substitute second column (Location): if in venue list, replace with 2-digit code; else leave as-is.
private func compressLocationColumn(_ value: String, venueNames: [String]) -> String {
    guard let idx = venueNames.firstIndex(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
        return value
    }
    return twoDigitCode(for: idx)
}

/// Substitute Type column: if in event type list, replace with 1-digit code; else leave as-is.
private func compressTypeColumn(_ value: String, eventTypes: [String]) -> String {
    guard let idx = eventTypes.firstIndex(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
        return value
    }
    return oneDigitCodeForType(index: idx)
}

/// Reverse: 2-digit code → band name, or return original if not a valid code.
private func decompressBandColumn(_ value: String, bandNames: [String]) -> String {
    if let idx = indexFromTwoDigitCode(value), idx < bandNames.count {
        return bandNames[idx]
    }
    return value
}

private func decompressLocationColumn(_ value: String, venueNames: [String]) -> String {
    if let idx = indexFromTwoDigitCode(value), idx < venueNames.count {
        return venueNames[idx]
    }
    return value
}

private func decompressTypeColumn(_ value: String, eventTypes: [String]) -> String {
    if let i = indexFromOneDigitTypeCode(value), i < eventTypes.count {
        return eventTypes[i]
    }
    return value
}

/// CSV header expected by ScheduleCSVImporter (order matters for parsing).
private let scheduleCSVHeader = "Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL,ImageDate"

/// QR payload omits Description URL, ImageURL, ImageDate to keep each chunk small and scannable; header and rows use 8 columns (Band–Notes only).
private let scheduleQRHeader = "Band,Location,Date,Day,Start Time,End Time,Type,Notes"

/// Number of columns in schedule CSV (for padding on decompress after trailing-comma strip).
private let scheduleCSVColumnCount = 11

private let dropboxURLPrefix = "https://www.dropbox.com/"
private let dropboxURLPlaceholder = "!DB!"

/// Shorten date for QR: 01/29/2026 -> 1/29/26 (no leading zeros, 2-digit year).
private func shortenDateForQR(_ date: String) -> String {
    let parts = date.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 3,
          let m = Int(parts[0]), let d = Int(parts[1]), let y = Int(parts[2]),
          (1...12).contains(m), (1...31).contains(d), y >= 2000, y <= 2099 else {
        return date
    }
    let yy = y % 100
    return "\(m)/\(d)/\(yy)"
}

/// Expand date from QR: 1/29/26 -> 01/29/2026 (MM/DD/YYYY with leading zeros).
private func expandDateFromQR(_ date: String) -> String {
    let parts = date.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 3,
          let m = Int(parts[0]), let d = Int(parts[1]), let y = Int(parts[2]),
          (1...12).contains(m), (1...31).contains(d) else {
        return date
    }
    let year: Int
    if y >= 100 { year = y }
    else if y >= 0, y <= 99 { year = 2000 + y }
    else { return date }
    return String(format: "%02d/%02d/%04d", m, d, year)
}

/// Shorten time for QR: 00,15,30,45 min → one digit or empty. 19:00→19:, 19:15→19:1, 19:30→19:2, 19:45→19:3. Other times as-is (e.g. 19:10).
private func shortenTimeForQR(_ time: String) -> String {
    let parts = time.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 2,
          let h = Int(parts[0].trimmingCharacters(in: .whitespaces)),
          (0...23).contains(h) else {
        return time
    }
    let minPart = parts[1].trimmingCharacters(in: .whitespaces)
    guard let m = Int(minPart), (0...59).contains(m) else {
        return time
    }
    switch m {
    case 0: return "\(h):"
    case 15: return "\(h):1"
    case 30: return "\(h):2"
    case 45: return "\(h):3"
    default: return time
    }
}

/// Expand time from QR: single digit after colon is shortcut. 19:→19:00, 19:1→19:15, 19:2→19:30, 19:3→19:45. Two digits or other as-is.
private func expandTimeFromQR(_ time: String) -> String {
    let parts = time.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 2,
          let h = Int(parts[0].trimmingCharacters(in: .whitespaces)),
          (0...23).contains(h) else {
        return time
    }
    let minPart = parts[1].trimmingCharacters(in: .whitespaces)
    if minPart.isEmpty {
        return String(format: "%02d:00", h)
    }
    if minPart.count == 1, let digit = Int(minPart), (0...3).contains(digit) {
        let m = [0: 0, 1: 15, 2: 30, 3: 45][digit] ?? 0
        return String(format: "%02d:%02d", h, m)
    }
    if let m = Int(minPart), (0...59).contains(m) {
        return String(format: "%02d:%02d", h, m)
    }
    return time
}

/// Shorten day for QR: "Day 2" -> "2". Leave other formats unchanged (e.g. "1/.27").
private func shortenDayForQR(_ day: String) -> String {
    let trimmed = day.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("Day "), trimmed.count > 4 {
        let suffix = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        if suffix.allSatisfy(\.isNumber), !suffix.isEmpty { return suffix }
    }
    return day
}

/// Expand day from QR: "2" -> "Day 2". Leave non-numeric unchanged.
private func expandDayFromQR(_ day: String) -> String {
    let trimmed = day.trimmingCharacters(in: .whitespaces)
    guard trimmed.allSatisfy(\.isNumber), !trimmed.isEmpty else { return day }
    return "Day \(trimmed)"
}

/// Preprocess CSV before compression: shorten Dropbox URLs, strip trailing empty columns (trailing commas).
private func preprocessCSVForCompression(_ csv: String) -> String {
    var out = csv.replacingOccurrences(of: dropboxURLPrefix, with: dropboxURLPlaceholder)
    let lines = out.components(separatedBy: .newlines)
    out = lines.map { line in
        line.replacingOccurrences(of: #",+$"#, with: "", options: .regularExpression)
    }.joined(separator: "\n")
    return out
}

/// Postprocess CSV after decompression: expand Dropbox placeholder, ensure rows have expected column count. QR payload has 8 columns (Band–Notes only); we pad to 11 (insert empty Description URL, append empty ImageURL, ImageDate) so importer is unchanged.
private func postprocessCSVAfterDecompression(_ csv: String) -> String {
    let expanded = csv.replacingOccurrences(of: dropboxURLPlaceholder, with: dropboxURLPrefix)
    let lines = expanded.components(separatedBy: .newlines)
    let result = lines.map { line -> String in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return line }
        var fields = parseCSVLine(trimmed)
        if fields.count >= scheduleCSVColumnCount { return line }
        if fields.first?.lowercased() == "band" {
            return scheduleCSVHeader
        }
        if fields.count == 8 {
            fields.insert("", at: 7)
            fields.append("")
            fields.append("")
        }
        while fields.count < scheduleCSVColumnCount {
            fields.append("")
        }
        return buildCSVLine(fields)
    }.joined(separator: "\n")
    return result
}

/// Parse one CSV line respecting quoted fields (simple: no escaped quotes).
private func parseCSVLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    for ch in line {
        if ch == "\"" {
            inQuotes.toggle()
        } else if (ch == "," && !inQuotes) {
            fields.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }
    fields.append(current)
    return fields
}

/// Escape a CSV field (quote if contains comma or newline).
private func escapeCSVField(_ s: String) -> String {
    if s.contains(",") || s.contains("\n") || s.contains("\"") {
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return s
}

/// Build a single CSV line from fields.
private func buildCSVLine(_ fields: [String]) -> String {
    return fields.map { escapeCSVField($0) }.joined(separator: ",")
}

// MARK: - Public API

enum ScheduleQRCompressionError: Error {
    case emptySchedule
    case compressionFailed
    case decompressionFailed(reason: String?)

    static var decompressionFailed: ScheduleQRCompressionError { .decompressionFailed(reason: nil) }
}

extension ScheduleQRCompressionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptySchedule: return "Schedule is empty."
        case .compressionFailed: return "Compression failed."
        case .decompressionFailed(let reason):
            return reason.map { "Decompression failed: \($0)" } ?? "Decompression failed."
        }
    }
}

// MARK: - LZMA (single QR binary payload)

/// Max bytes per QR for binary payload (Version 40 Low). Single or two-QR schedule share.
private let maxBytesPerBinaryQR: Int = 2953

/// Payload type byte: 0 = full schedule (1 QR), 1 = chunk 1 of 2, 2 = chunk 2 of 2. Followed by 4-byte LE size + LZMA.
let scheduleQRTypeFull: UInt8 = 0
let scheduleQRTypeChunk1: UInt8 = 1
let scheduleQRTypeChunk2: UInt8 = 2

/// Compress with LZMA and prepend 4-byte LE uncompressed size. Returns raw bytes for binary QR.
private func compressForQR(source: Data) throws -> Data {
    let srcCount = source.count
    let dstCapacity = srcCount + 4096
    var dstBuffer = [UInt8](repeating: 0, count: dstCapacity)
    let written: Int = source.withUnsafeBytes { srcRaw in
        guard let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        return compression_encode_buffer(&dstBuffer, dstCapacity, srcPtr, srcCount, nil, COMPRESSION_LZMA)
    }
    guard written > 0 else { throw ScheduleQRCompressionError.compressionFailed }
    var out = Data()
    var le = UInt32(srcCount).littleEndian
    out.append(Data(bytes: &le, count: 4))
    out.append(Data(bytes: &dstBuffer, count: written))
    let headerHex = String(format: "%02X%02X%02X%02X", out[0], out[1], out[2], out[3])
    print("[QRCompress] payload first4=\(headerHex) uncompressedSize=\(srcCount) totalPayload=\(out.count)")
    return out
}

/// Decompress LZMA stream (4-byte LE size header + compressed bytes).
private func decompressFromQR(compressed: Data) throws -> Data {
    guard compressed.count > 4 else {
        print("[QRDecompress] FAIL: payload too short count=\(compressed.count)")
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Payload too short (\(compressed.count) bytes)")
    }
    let b0 = UInt32(compressed[0]), b1 = UInt32(compressed[1]), b2 = UInt32(compressed[2]), b3 = UInt32(compressed[3])
    let uncompressedSize = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    let n = Int(uncompressedSize)
    let headerHex = String(format: "%02X%02X%02X%02X", compressed[0], compressed[1], compressed[2], compressed[3])
    print("[QRDecompress] payloadCount=\(compressed.count) headerHex=\(headerHex) n=\(n)")
    guard n > 0, n <= 2_000_000 else {
        print("[QRDecompress] FAIL: invalid size header n=\(n)")
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Invalid size header (n=\(n))")
    }
    let payloadStart = compressed.index(compressed.startIndex, offsetBy: 4)
    let payloadData = compressed.subdata(in: payloadStart..<compressed.endIndex)
    let scratchSize = compression_decode_scratch_buffer_size(COMPRESSION_LZMA)
    var scratch = [UInt8](repeating: 0, count: scratchSize)
    var dstBuffer = [UInt8](repeating: 0, count: n)
    let written: Int = payloadData.withUnsafeBytes { srcRaw in
        guard let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        return compression_decode_buffer(&dstBuffer, n, srcPtr, payloadData.count, &scratch, COMPRESSION_LZMA)
    }
    print("[QRDecompress] lzmaBytes=\(payloadData.count) written=\(written)")
    guard written == n else {
        print("[QRDecompress] FAIL: written=\(written) expected=\(n)")
        throw ScheduleQRCompressionError.decompressionFailed(reason: "LZMA decode returned \(written), expected \(n)")
    }
    return Data(bytes: &dstBuffer, count: written)
}

/// Split schedule into three CSV chunks by uncompressed byte size (~1/3 each) so each QR stays scannable after Base64. Client reassembles by position (top, middle, bottom).
func compressScheduleForThreeQRs(csvString: String, eventYear: Int) throws -> (top: Data, middle: Data, bottom: Data) {
    let preprocessed = preprocessCSVForCompression(csvString)
    let lines = preprocessed.components(separatedBy: .newlines)
    guard !lines.isEmpty else { throw ScheduleQRCompressionError.emptySchedule }

    var headerLine: String?
    var dataLines: [String] = []
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        let fields = parseCSVLine(trimmed)
        if fields.count >= 7 && fields[0].lowercased() == "band" {
            headerLine = trimmed
            continue
        }
        dataLines.append(trimmed)
    }
    guard let header = headerLine else { throw ScheduleQRCompressionError.emptySchedule }
    guard dataLines.count >= 3 else {
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Schedule must have at least 3 data rows for three-QR share.")
    }

    var totalDataBytes = 0
    for line in dataLines { totalDataBytes += line.utf8.count + 1 }
    let third = totalDataBytes / 3
    var accumulated = 0
    var split1 = dataLines.count
    var split2 = dataLines.count
    for (i, line) in dataLines.enumerated() {
        accumulated += line.utf8.count + 1
        if split1 == dataLines.count, accumulated >= third, i + 1 < dataLines.count {
            split1 = i + 1
        }
        if split2 == dataLines.count, accumulated >= 2 * third, i + 1 < dataLines.count {
            split2 = i + 1
            break
        }
    }

    let chunk1Lines = [header] + Array(dataLines[0..<split1])
    let chunk2Lines = Array(dataLines[split1..<split2])
    let chunk3Lines = Array(dataLines[split2..<dataLines.count])
    let topPayload = try compressScheduleForQRData(csvString: chunk1Lines.joined(separator: "\n"), eventYear: eventYear)
    let middlePayload = try compressScheduleForQRData(csvString: chunk2Lines.joined(separator: "\n"), eventYear: eventYear)
    let bottomPayload = try compressScheduleForQRData(csvString: chunk3Lines.joined(separator: "\n"), eventYear: eventYear)
    // Host-side diagnostic: compare with [QRScan] on client to find where bytes change
    let hex = { (d: Data) in d.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ") }
    print("[QRHost] top=\(topPayload.count) first16=\(hex(topPayload))")
    print("[QRHost] middle=\(middlePayload.count) first16=\(hex(middlePayload))")
    print("[QRHost] bottom=\(bottomPayload.count) first16=\(hex(bottomPayload))")
    return (top: topPayload, middle: middlePayload, bottom: bottomPayload)
}

/// Scanner/QR pipeline can corrupt the first 4 bytes (size header) while leaving LZMA intact. Try normal header+offset, then try skipping 4 bytes and probing plausible uncompressed sizes.
private func rawPayloadFromScanned(_ payload: Data) -> Data {
    guard payload.count > 8 else { return payload }
    let maxSkip = min(32, payload.count - 8)
    for offset in 0...maxSkip {
        let slice = payload.subdata(in: offset..<payload.endIndex)
        guard slice.count > 4 else { continue }
        let b0 = UInt32(slice[0]), b1 = UInt32(slice[1]), b2 = UInt32(slice[2]), b3 = UInt32(slice[3])
        let n = Int(b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
        guard n > 0, n <= 2_000_000 else { continue }
        let payloadStart = 4
        let lzmaLen = slice.count - payloadStart
        guard lzmaLen > 0 else { continue }
        let scratchSize = compression_decode_scratch_buffer_size(COMPRESSION_LZMA)
        var scratch = [UInt8](repeating: 0, count: scratchSize)
        var dstBuffer = [UInt8](repeating: 0, count: n)
        let written: Int = slice.subdata(in: payloadStart..<slice.endIndex).withUnsafeBytes { srcRaw in
            guard let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return compression_decode_buffer(&dstBuffer, n, srcPtr, lzmaLen, &scratch, COMPRESSION_LZMA)
        }
        if written == n {
            if offset > 0 {
                print("[QRDecompress] Skipped \(offset) leading bytes → valid payload \(slice.count) bytes")
            }
            return slice
        }
    }
    // Recovery: first 4–10 bytes may be corrupted (or duplicated header); LZMA may start at 0,4,6,8,9,10. Try trimming end. Probe n step 1.
    let scratchSize = compression_decode_scratch_buffer_size(COMPRESSION_LZMA)
    var scratch = [UInt8](repeating: 0, count: scratchSize)
    let candidateSizes: [Int] = [2009, 2037, 2613, 2000, 2500, 2100, 2600, 1500, 3000, 1000, 3500, 2035, 2040, 2025, 776, 768, 552]
    var didLogProbe = false
    for lzmaStart in [0, 4, 5, 6, 7, 8, 9, 10] where payload.count > lzmaStart + 64 {
        let fullLzma = payload.subdata(in: lzmaStart..<payload.endIndex)
        let trimMax = min(10, fullLzma.count - 64)
        for trim in 0...trimMax {
            let lzmaLen = fullLzma.count - trim
            let lzmaData = fullLzma.subdata(in: 0..<lzmaLen)
            for n in candidateSizes where n <= 2_000_000 {
                var dstBuffer = [UInt8](repeating: 0, count: n)
                let written: Int = lzmaData.withUnsafeBytes { srcRaw in
                    guard let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    return compression_decode_buffer(&dstBuffer, n, srcPtr, lzmaData.count, &scratch, COMPRESSION_LZMA)
                }
                if !didLogProbe, lzmaStart == 4, trim == 0, n == 2037, written > 0 {
                    print("[QRDecompress] probe lzmaStart=4 trim=0 n=2037 → written=\(written) (first4 decoded: \(dstBuffer.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " ")))")
                    didLogProbe = true
                }
                if written == n {
                    var out = Data()
                    var le = UInt32(n).littleEndian
                    out.append(Data(bytes: &le, count: 4))
                    out.append(lzmaData)
                    print("[QRDecompress] Recovered: first \(lzmaStart) bytes corrupted, trim=\(trim), n=\(n) → payload \(out.count) bytes")
                    return out
                }
            }
            for n in 1000...3500 {
                var dstBuffer = [UInt8](repeating: 0, count: n)
                let written: Int = lzmaData.withUnsafeBytes { srcRaw in
                    guard let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    return compression_decode_buffer(&dstBuffer, n, srcPtr, lzmaData.count, &scratch, COMPRESSION_LZMA)
                }
                if written == n {
                    var out = Data()
                    var le = UInt32(n).littleEndian
                    out.append(Data(bytes: &le, count: 4))
                    out.append(lzmaData)
                    print("[QRDecompress] Recovered: first \(lzmaStart) bytes corrupted, trim=\(trim), n=\(n) (probe) → payload \(out.count) bytes")
                    return out
                }
            }
        }
    }
    // Diagnostic: try decoding bytes 4..end (and trimmed) as LZMA with plausible n to find if stream is valid
    var diagnosticHadMatch = false
    if payload.count > 8 {
        let scratchSize = compression_decode_scratch_buffer_size(COMPRESSION_LZMA)
        var scratch = [UInt8](repeating: 0, count: scratchSize)
        for trimEnd in 0...min(6, payload.count - 4 - 64) {
            let lzmaLen = payload.count - 4 - trimEnd
            let lzmaFrom4 = payload.subdata(in: 4..<(payload.endIndex - trimEnd))
            for tryN in [2037, 2613, 2009, 1973, 2500, 2100] {
                var dst = [UInt8](repeating: 0, count: tryN)
                let w = lzmaFrom4.withUnsafeBytes { srcRaw in
                    guard let src = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    return compression_decode_buffer(&dst, tryN, src, lzmaLen, &scratch, COMPRESSION_LZMA)
                }
                if w > 0 {
                    diagnosticHadMatch = true
                    let sample = dst.prefix(40).map { String(format: "%02X", $0) }.joined(separator: " ")
                    print("[QRDecompress] diagnostic trimEnd=\(trimEnd) n=\(tryN) → written=\(w) first40hex=\(sample)")
                    let previewLen = min(w, 80)
                    if let s = String(bytes: dst.prefix(previewLen), encoding: .utf8) { print("[QRDecompress] decoded preview: \(s)") }
                    if w == tryN {
                        print("[QRDecompress] diagnostic: exact match trimEnd=\(trimEnd) n=\(tryN) — recovery should have found this")
                    }
                }
            }
        }
        if !diagnosticHadMatch {
            print("[QRDecompress] diagnostic: tried bytes 4..end (trimEnd 0..6), n in [2037,2613,2009,...] — all written=0 (Vision payload not valid LZMA)")
        }
    }
    let first16 = payload.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
    print("[QRDecompress] No valid header+LZMA at any offset 0..\(maxSkip), payload.count=\(payload.count), first16=\(first16)")
    let decoded: Data? = {
        if let str = String(data: payload, encoding: .utf8), let d = Data(base64Encoded: str), d.count > 4 { return d }
        let latin1 = String(data: payload, encoding: .isoLatin1)
        guard let str = latin1, let d = Data(base64Encoded: str), d.count > 4 else { return nil }
        return d
    }()
    guard let decoded = decoded else { return payload }
    let d0 = UInt32(decoded[0]), d1 = UInt32(decoded[1]), d2 = UInt32(decoded[2]), d3 = UInt32(decoded[3])
    let dn = Int(d0 | (d1 << 8) | (d2 << 16) | (d3 << 24))
    if dn > 0, dn <= 2_000_000 {
        print("[QRDecompress] Base64-decoded payload: scanned \(payload.count) → binary \(decoded.count)")
        return decoded
    }
    return payload
}

// MARK: - One or two binary QRs (BinaryQRScanner; type byte + 4-byte size + LZMA)

/// Compress schedule for 1 or 2 binary QRs. If compressed full schedule fits in maxBytesPerBinaryQR, returns 1 payload; else 2. Each payload: type (0/1/2) + 4-byte LE size + LZMA.
func compressScheduleForOneOrTwoQRs(csvString: String, eventYear: Int) throws -> [Data] {
    let singlePayload = try compressScheduleForQRData(csvString: csvString, eventYear: eventYear)
    var withType = Data()
    withType.append(scheduleQRTypeFull)
    withType.append(singlePayload)
    if withType.count <= maxBytesPerBinaryQR {
        print("[QRHost] 1 QR, \(withType.count) bytes")
        return [withType]
    }
    let preprocessed = preprocessCSVForCompression(csvString)
    let lines = preprocessed.components(separatedBy: .newlines)
    guard !lines.isEmpty else { throw ScheduleQRCompressionError.emptySchedule }
    var headerLine: String?
    var dataLines: [String] = []
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        let fields = parseCSVLine(trimmed)
        if fields.count >= 7 && fields[0].lowercased() == "band" {
            headerLine = trimmed
            continue
        }
        dataLines.append(trimmed)
    }
    guard let header = headerLine, dataLines.count >= 2 else {
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Schedule needs at least 2 data rows for two-QR share.")
    }
    let mid = dataLines.count / 2
    let chunk1 = [header] + Array(dataLines[0..<mid])
    let chunk2 = Array(dataLines[mid..<dataLines.count])
    let p1 = try compressScheduleForQRData(csvString: chunk1.joined(separator: "\n"), eventYear: eventYear)
    let p2 = try compressScheduleForQRData(csvString: chunk2.joined(separator: "\n"), eventYear: eventYear)
    var out1 = Data()
    out1.append(scheduleQRTypeChunk1)
    out1.append(p1)
    var out2 = Data()
    out2.append(scheduleQRTypeChunk2)
    out2.append(p2)
    guard out1.count <= maxBytesPerBinaryQR, out2.count <= maxBytesPerBinaryQR else {
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Schedule too large for two QRs.")
    }
    print("[QRHost] 2 QRs, \(out1.count) + \(out2.count) bytes")
    return [out1, out2]
}

/// Parse type byte from payload. Returns (type, payloadWithoutType) where payloadWithoutType is 4-byte size + LZMA.
func scheduleQRBinaryPayloadType(_ payload: Data) -> (type: UInt8, body: Data)? {
    guard payload.count > 5 else { return nil }
    let t = payload[0]
    guard t == scheduleQRTypeFull || t == scheduleQRTypeChunk1 || t == scheduleQRTypeChunk2 else { return nil }
    return (t, payload.subdata(in: 1..<payload.count))
}

/// Decompress one or two binary QR payloads (type + 4-byte size + LZMA) and merge into one CSV.
func decompressAndMergeOneOrTwoPayloads(_ payloads: [Data], eventYear: Int) throws -> String {
    guard !payloads.isEmpty, payloads.count <= 2 else {
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Expected 1 or 2 payloads, got \(payloads.count).")
    }
    var bodies: [Data] = []
    for (i, payload) in payloads.enumerated() {
        guard let (_, body) = scheduleQRBinaryPayloadType(payload) else {
            throw ScheduleQRCompressionError.decompressionFailed(reason: "Payload \(i + 1) has invalid type header.")
        }
        bodies.append(body)
    }
    if payloads.count == 1 {
        return try decompressScheduleFromQR(compressedData: bodies[0], eventYear: eventYear)
    }
    let csv1 = try decompressScheduleFromQR(compressedData: bodies[0], eventYear: eventYear)
    let csv2 = try decompressScheduleFromQR(compressedData: bodies[1], eventYear: eventYear)
    let sep = csv1.hasSuffix("\n") ? "" : "\n"
    return csv1 + sep + csv2
}

/// Decompress and merge three QR payloads (top, middle, bottom in order) into one CSV. Use when scanner returns three payloads from one image.
func decompressAndMergeThreePayloads(topPayload: Data, middlePayload: Data, bottomPayload: Data, eventYear: Int) throws -> String {
    let topRaw = rawPayloadFromScanned(topPayload)
    let middleRaw = rawPayloadFromScanned(middlePayload)
    let bottomRaw = rawPayloadFromScanned(bottomPayload)
    let csv1 = try decompressScheduleFromQR(compressedData: topRaw, eventYear: eventYear)
    let csv2 = try decompressScheduleFromQR(compressedData: middleRaw, eventYear: eventYear)
    let csv3 = try decompressScheduleFromQR(compressedData: bottomRaw, eventYear: eventYear)
    let sep = csv1.hasSuffix("\n") ? "" : "\n"
    return csv1 + sep + csv2 + (csv2.hasSuffix("\n") ? "" : "\n") + csv3
}

// MARK: - Six QR plain UTF-8 (no compression)

/// Max bytes per QR for reliable scan (Version 40 Low). Use lower to keep density manageable.
private let maxBytesPerPlainQR: Int = 2650
/// Tighter limit for 16-chunk "low density" QRs so each code is easier to scan.
private let maxBytesPerPlainQRLowDensity: Int = 1200
/// Even tighter for 24-chunk "very low density" QRs (~800 bytes each).
private let maxBytesPerPlainQRVeryLowDensity: Int = 800

/// Build shortened 8-column CSV string (same format as LZMA path) for plain-UTF-8 chunks. Returns full shortened CSV.
private func buildShortenedScheduleCSV(csvString: String, eventYear: Int) throws -> String {
    let preprocessed = preprocessCSVForCompression(csvString)
    let bandNames = canonicalBandNames(forYear: eventYear)
    let venueNames = canonicalVenueNames()
    let eventTypes = canonicalEventTypes()
    let lines = preprocessed.components(separatedBy: .newlines)
    guard !lines.isEmpty else { throw ScheduleQRCompressionError.emptySchedule }
    var outLines: [String] = []
    for (i, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        let fields = parseCSVLine(trimmed)
        if fields.count < 7 {
            outLines.append(line)
            continue
        }
        if i == 0 && fields[0].lowercased() == "band" {
            outLines.append(scheduleQRHeader)
            continue
        }
        let notes = fields.count > 8 ? fields[8] : ""
        let newFields: [String] = [
            compressBandColumn(fields[0], bandNames: bandNames),
            compressLocationColumn(fields[1], venueNames: venueNames),
            shortenDateForQR(fields[2]),
            shortenDayForQR(fields[3]),
            shortenTimeForQR(fields[4]),
            shortenTimeForQR(fields[5]),
            compressTypeColumn(fields[6], eventTypes: eventTypes),
            notes
        ]
        outLines.append(buildCSVLine(newFields))
    }
    return outLines.joined(separator: "\n")
}

/// Split schedule into 6 plain UTF-8 chunks (no LZMA), each ≤ maxBytesPerPlainQR. Chunk 1 has header + rows; chunks 2–6 rows only. Order: row-major (top-left → bottom-right).
func splitScheduleForSixQRs(csvString: String, eventYear: Int) throws -> [Data] {
    let fullShort = try buildShortenedScheduleCSV(csvString: csvString, eventYear: eventYear)
    let lines = fullShort.components(separatedBy: .newlines)
    guard !lines.isEmpty else { throw ScheduleQRCompressionError.emptySchedule }
    let headerLine = lines[0]
    let dataLines = Array(lines.dropFirst()).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    guard dataLines.count >= 6 else {
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Schedule needs at least 6 data rows for six-QR share.")
    }
    var totalDataBytes = 0
    for line in dataLines { totalDataBytes += line.utf8.count + 1 }
    let bytesPerChunk = max(1, totalDataBytes / 6)
    var accumulated = 0
    var splits: [Int] = []
    for (i, line) in dataLines.enumerated() {
        accumulated += line.utf8.count + 1
        if splits.count < 5, accumulated >= (splits.count + 1) * bytesPerChunk, i + 1 < dataLines.count {
            splits.append(i + 1)
        }
    }
    if splits.count < 5 {
        for k in splits.count..<5 {
            let idx = (dataLines.count * (k + 1)) / 6
            splits.append(min(idx, dataLines.count - 1))
        }
        splits = Array(Set(splits)).sorted()
    }
    splits = Array(splits.prefix(5)).sorted()
    var chunkLines: [[String]] = []
    chunkLines.append([headerLine] + Array(dataLines[0..<splits[0]]))
    for s in 0..<5 {
        let start = splits[s]
        let end = s + 1 < splits.count ? splits[s + 1] : dataLines.count
        chunkLines.append(Array(dataLines[start..<end]))
    }
    var payloads: [Data] = []
    for (idx, chunk) in chunkLines.enumerated() {
        let text = chunk.joined(separator: "\n")
        guard let data = text.data(using: .utf8) else { throw ScheduleQRCompressionError.compressionFailed }
        if data.count > maxBytesPerPlainQR {
            throw ScheduleQRCompressionError.decompressionFailed(reason: "Chunk \(idx + 1) is \(data.count) bytes; max \(maxBytesPerPlainQR) per QR.")
        }
        payloads.append(data)
        print("[QRHost] 6-QR chunk \(idx + 1)=\(data.count) bytes")
    }
    return payloads
}

/// Merge 6 plain UTF-8 QR payloads (order: row-major, same as scanner sort) into one CSV. No LZMA; payloads are raw UTF-8 shortened CSV.
func mergeSixPlainUTF8Payloads(_ payloads: [Data], eventYear: Int) throws -> String {
    guard payloads.count == 6 else {
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Expected 6 payloads, got \(payloads.count).")
    }
    var parts: [String] = []
    for (i, data) in payloads.enumerated() {
        guard let s = String(data: data, encoding: .utf8), !s.isEmpty else {
            throw ScheduleQRCompressionError.decompressionFailed(reason: "Chunk \(i + 1) is not valid UTF-8.")
        }
        parts.append(s.trimmingCharacters(in: .whitespaces))
    }
    let combined = parts.joined(separator: "\n")
    let fullCSV = decompressCSVToFull(compressedCSV: combined, eventYear: eventYear)
    return postprocessCSVAfterDecompression(fullCSV)
}

// MARK: - Multi-chunk plain UTF-8 (8 or 16 chunks; low density for scannability)

/// Split schedule into N plain UTF-8 chunks with "70K,i,N" marker. Uses lower max bytes for 16/24 for scannability.
func splitScheduleForPlainQRs(csvString: String, eventYear: Int, chunkCount: Int) throws -> [Data] {
    let maxBytes: Int
    switch chunkCount {
    case 24: maxBytes = maxBytesPerPlainQRVeryLowDensity
    case 16: maxBytes = maxBytesPerPlainQRLowDensity
    default: maxBytes = maxBytesPerPlainQR
    }
    let fullShort = try buildShortenedScheduleCSV(csvString: csvString, eventYear: eventYear)
    let lines = fullShort.components(separatedBy: .newlines)
    guard !lines.isEmpty else { throw ScheduleQRCompressionError.emptySchedule }
    let headerLine = lines[0]
    let dataLines = Array(lines.dropFirst()).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    guard dataLines.count >= chunkCount else {
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Schedule needs at least \(chunkCount) data rows.")
    }
    let splitCount = chunkCount - 1
    var totalDataBytes = 0
    for line in dataLines { totalDataBytes += line.utf8.count + 1 }
    let bytesPerChunk = max(1, totalDataBytes / chunkCount)
    var accumulated = 0
    var splits: [Int] = []
    for (i, line) in dataLines.enumerated() {
        accumulated += line.utf8.count + 1
        if splits.count < splitCount, accumulated >= (splits.count + 1) * bytesPerChunk, i + 1 < dataLines.count {
            splits.append(i + 1)
        }
    }
    if splits.count < splitCount {
        for k in splits.count..<splitCount {
            let idx = (dataLines.count * (k + 1)) / chunkCount
            splits.append(min(idx, dataLines.count - 1))
        }
        splits = Array(Set(splits)).sorted()
    }
    splits = Array(splits.prefix(splitCount)).sorted()
    var chunkLines: [[String]] = []
    chunkLines.append([headerLine] + Array(dataLines[0..<splits[0]]))
    for s in 0..<splitCount {
        let start = splits[s]
        let end = s + 1 < splits.count ? splits[s + 1] : dataLines.count
        chunkLines.append(Array(dataLines[start..<end]))
    }
    var payloads: [Data] = []
    for (idx, chunk) in chunkLines.enumerated() {
        let chunkText = chunk.joined(separator: "\n")
        let marker = "70K,\(idx + 1),\(chunkCount)"
        let text = marker + "\n" + chunkText
        guard let data = text.data(using: .utf8) else { throw ScheduleQRCompressionError.compressionFailed }
        if data.count > maxBytes {
            throw ScheduleQRCompressionError.decompressionFailed(reason: "Chunk \(idx + 1) is \(data.count) bytes; max \(maxBytes) per QR.")
        }
        payloads.append(data)
        print("[QRHost] \(chunkCount)-QR chunk \(idx + 1)=\(data.count) bytes")
    }
    return payloads
}

/// Parse first line "70K,<index>,<total>" from schedule QR payload. Returns (index 1-based, total) or nil. Supports total 8, 16, or 24.
func scheduleQRChunkIndex(from payload: Data) -> (index: Int, total: Int)? {
    guard let s = String(data: payload, encoding: .utf8),
          let firstLine = s.split(separator: "\n").first,
          firstLine.hasPrefix("70K,") else { return nil }
    let parts = firstLine.split(separator: ",")
    guard parts.count >= 3,
          let idx = Int(parts[1]), let total = Int(parts[2]),
          idx >= 1, idx <= total, (total == 8 || total == 16 || total == 24) else { return nil }
    return (idx, total)
}

/// Strip the "70K,<i>,<n>" marker line from the start of a chunk string.
private func stripScheduleChunkMarker(_ s: String) -> String {
    let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
    guard let first = lines.first, first.hasPrefix("70K,") else { return s }
    return lines.dropFirst().joined(separator: "\n")
}

/// Merge 8, 16, or 24 plain UTF-8 QR payloads (with "70K,i,N" marker). Strip markers, concatenate, decompress, postprocess.
func mergePlainUTF8SchedulePayloads(_ payloads: [Data], eventYear: Int) throws -> String {
    guard payloads.count == 8 || payloads.count == 16 || payloads.count == 24 else {
        throw ScheduleQRCompressionError.decompressionFailed(reason: "Expected 8, 16, or 24 payloads, got \(payloads.count).")
    }
    var parts: [String] = []
    for (i, data) in payloads.enumerated() {
        guard let s = String(data: data, encoding: .utf8), !s.isEmpty else {
            throw ScheduleQRCompressionError.decompressionFailed(reason: "Chunk \(i + 1) is not valid UTF-8.")
        }
        let trimmed = stripScheduleChunkMarker(s.trimmingCharacters(in: .whitespaces))
        parts.append(trimmed)
    }
    let combined = parts.joined(separator: "\n")
    let fullCSV = decompressCSVToFull(compressedCSV: combined, eventYear: eventYear)
    return postprocessCSVAfterDecompression(fullCSV)
}

/// Compress schedule for a single binary QR: preprocess (Dropbox URL shorten, strip trailing commas), substitute codes (band/venue/type/date/time/day), then LZMA with size header. Returns raw bytes (≤ ~2953) for one QR.
func compressScheduleForQRData(csvString: String, eventYear: Int) throws -> Data {
    let preprocessed = preprocessCSVForCompression(csvString)
    let bandNames = canonicalBandNames(forYear: eventYear)
    let venueNames = canonicalVenueNames()
    let eventTypes = canonicalEventTypes()
    let lines = preprocessed.components(separatedBy: .newlines)
    guard !lines.isEmpty else { throw ScheduleQRCompressionError.emptySchedule }

    var outLines: [String] = []
    for (i, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        let fields = parseCSVLine(trimmed)
        if fields.count < 7 {
            outLines.append(line)
            continue
        }
        if i == 0 && fields[0].lowercased() == "band" {
            outLines.append(scheduleQRHeader)
            continue
        }
        let notes = fields.count > 8 ? fields[8] : ""
        var newFields: [String] = [
            compressBandColumn(fields[0], bandNames: bandNames),
            compressLocationColumn(fields[1], venueNames: venueNames),
            shortenDateForQR(fields[2]),
            shortenDayForQR(fields[3]),
            shortenTimeForQR(fields[4]),
            shortenTimeForQR(fields[5]),
            compressTypeColumn(fields[6], eventTypes: eventTypes),
            notes
        ]
        outLines.append(buildCSVLine(newFields))
    }
    let compressedCSV = outLines.joined(separator: "\n")
    guard let csvData = compressedCSV.data(using: .utf8) else { throw ScheduleQRCompressionError.compressionFailed }
    let beforeBytes = csvData.count
    let payload = try compressForQR(source: csvData)
    let afterBytes = payload.count
    print("[QRCompress] before=\(beforeBytes) bytes → after=\(afterBytes) bytes (ratio \(String(format: "%.2f", Double(beforeBytes) / Double(max(1, afterBytes)))))")
    return payload
}

/// Decompress QR payload: binary = 4-byte LE size + LZMA. Caller must pass raw binary (after Base64 decode if QR contained Base64).
func decompressScheduleFromQR(compressedData: Data, eventYear: Int) throws -> String {
    let decompressed = try decompressFromQR(compressed: compressedData)
    let compressedCSV = String(decoding: decompressed, as: UTF8.self)
    let fullCSV = decompressCSVToFull(compressedCSV: compressedCSV, eventYear: eventYear)
    return postprocessCSVAfterDecompression(fullCSV)
}

private func decompressCSVToFull(compressedCSV: String, eventYear: Int) -> String {
    let bandNames = canonicalBandNames(forYear: eventYear)
    let venueNames = canonicalVenueNames()
    let eventTypes = canonicalEventTypes()

    let lines = compressedCSV.components(separatedBy: .newlines)
    var outLines: [String] = []
    for (i, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        var fields = parseCSVLine(trimmed)
        if i == 0 && fields.first?.lowercased() == "band" {
            outLines.append(trimmed)
            continue
        }
        if fields.count >= 7 {
            fields[0] = decompressBandColumn(fields[0], bandNames: bandNames)
            fields[1] = decompressLocationColumn(fields[1], venueNames: venueNames)
            fields[2] = expandDateFromQR(fields[2])
            fields[3] = expandDayFromQR(fields[3])
            fields[4] = expandTimeFromQR(fields[4])
            fields[5] = expandTimeFromQR(fields[5])
            fields[6] = decompressTypeColumn(fields[6], eventTypes: eventTypes)
        }
        outLines.append(buildCSVLine(fields))
    }

    return outLines.joined(separator: "\n")
}

// MARK: - Export schedule to CSV (from SQLite events)

/// Build full schedule CSV string from current year's events (for host to compress and show as QR).
func exportScheduleCSV(eventYear: Int) -> String? {
    let events = DataManager.shared.fetchEvents(forYear: eventYear)
    if events.isEmpty { return nil }

    var lines: [String] = [scheduleCSVHeader]
    for event in events {
        let band = event.bandName
        let location = event.location ?? ""
        let date = event.date ?? ""
        let day = event.day ?? ""
        let startTime = event.startTime ?? ""
        let endTime = event.endTime ?? ""
        let type = event.eventType ?? ""
        let descUrl = event.descriptionUrl ?? ""
        let notes = event.notes ?? ""
        let imageUrl = event.eventImageUrl ?? ""
        let imageDate = ""
        let row = buildCSVLine([band, location, date, day, startTime, endTime, type, descUrl, notes, imageUrl, imageDate])
        lines.append(row)
    }
    return lines.joined(separator: "\n")
}
