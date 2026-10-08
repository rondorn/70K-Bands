//
//  SiriCatalogIndexer.swift
//  70K Bands
//
//  Donates festival bands and shows to the system semantic index.
//  The first pass downloads every year's band and schedule CSV.
//  After that, past years are left alone and the current year is refreshed
//  from the app database on a later launch. Nothing here is shown in the app.
//

import AppIntents
import CoreSpotlight
import CryptoKit
import Foundation
import FoundationModels
import GeoToolbox
import os

/// Visible in Console.app on a Mac with the phone connected: filter on `SIRI_INDEX`.
private let siriIndexLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SiriCatalog", category: "SIRI_INDEX")

private func siriIndexNote(_ message: String) {
    siriIndexLog.notice("[SIRI_INDEX] \(message, privacy: .public)")
}

/// Starts the catalog pass. No-op below iOS 27, when new Siri is off, or when this app is excluded from Siri search.
enum SiriCatalogIndexer {
    static func start() {
        guard #available(iOS 27.0, *) else { return }
        SiriCatalogJob.kick()
    }
}

struct SiriCatalogYearLink: Equatable {
    var year: Int
    var artistURL: String
    var scheduleURL: String
}

enum SiriCatalogPointer {
    /// Year sections only. `Current` and `Default` are not extra years.
    /// A `Current` block is used only when that year has no section of its own.
    static func years(in pointerText: String) -> [SiriCatalogYearLink] {
        var sections: [String: [String: String]] = [:]
        for rawLine in pointerText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let (section, key, value) = splitPointerLine(line) else { continue }
            guard key == "artistUrl" || key == "scheduleUrl" || key == "eventYear" else { continue }
            sections[section, default: [:]][key] = value
        }

        var byYear: [Int: (artist: String, schedule: String)] = [:]
        for (section, fields) in sections {
            guard section.count == 4, let year = Int(section), year > 2000 else { continue }
            byYear[year] = (fields["artistUrl"] ?? "", fields["scheduleUrl"] ?? "")
        }

        if let currentYear = Int(sections["Current"]?["eventYear"] ?? ""),
           currentYear > 2000,
           byYear[currentYear] == nil {
            byYear[currentYear] = (
                sections["Current"]?["artistUrl"] ?? "",
                sections["Current"]?["scheduleUrl"] ?? ""
            )
        }

        return byYear.keys.sorted().map { year in
            let urls = byYear[year]!
            return SiriCatalogYearLink(year: year, artistURL: urls.artist, scheduleURL: urls.schedule)
        }
    }

    /// `Current::eventYear` from the pointer. This is the festival year, not the year the UI is browsing.
    static func currentYear(in pointerText: String) -> Int? {
        for rawLine in pointerText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let (section, key, value) = splitPointerLine(line) else { continue }
            guard section == "Current", key == "eventYear", let year = Int(value), year > 2000 else { continue }
            return year
        }
        return nil
    }

    /// `2014::artistUrl::https://…` and the one-colon typo `2014::artistUrl:https://…`.
    static func splitPointerLine(_ line: String) -> (section: String, key: String, value: String)? {
        guard let separator = line.range(of: "::") else { return nil }
        let section = String(line[..<separator.lowerBound])
        let rest = line[separator.upperBound...]
        if let second = rest.range(of: "::") {
            let key = String(rest[..<second.lowerBound])
            let value = String(rest[second.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !section.isEmpty, !key.isEmpty, !value.isEmpty else { return nil }
            return (section, key, value)
        }
        guard let colon = rest.range(of: ":"), rest[colon.upperBound...].hasPrefix("http") else { return nil }
        let key = String(rest[..<colon.lowerBound])
        let value = String(rest[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !section.isEmpty, !key.isEmpty, !value.isEmpty else { return nil }
        return (section, key, value)
    }
}

struct SiriCatalogCheckpointEntry: Codable, Equatable {
    var artistURL: String
    var scheduleURL: String
    var artistChecksum: String
    var scheduleChecksum: String
    var indexed: Bool

    func isCurrent(artistURL: String, scheduleURL: String, artistChecksum: String, scheduleChecksum: String) -> Bool {
        indexed
            && self.artistURL == artistURL
            && self.scheduleURL == scheduleURL
            && self.artistChecksum == artistChecksum
            && self.scheduleChecksum == scheduleChecksum
    }
}

@available(iOS 27.0, *)
private enum SiriCatalogGate {
    /// New Siri runs when Apple Intelligence is on. `isAvailable` is false when the
    /// device cannot run it or the person has not turned it on.
    static var isNewSiriActive: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Search content for this app is on unless the person turns it off.
    /// That switch is what lets Siri read the index.
    static var isEnabledForThisApp: Bool {
        CSSearchableIndex.isIndexingAvailable()
    }

    static var allowsWork: Bool {
        isNewSiriActive && isEnabledForThisApp
    }
}

@available(iOS 27.0, *)
private struct SiriCatalogCheckpoint: Codable {
    /// Bump when the donated record shape changes; older indexes are cleared and re-donated from saved files.
    static let currentFormat = 2

    var years: [String: SiriCatalogCheckpointEntry] = [:]
    var format: Int?
    var bandNoteIDs: [String]?
}

@available(iOS 27.0, *)
private struct StoredBand: Codable, Sendable {
    var id: String
    var name: String
    var year: Int
    var genre: String
    var country: String
    var sentence: String
}

@available(iOS 27.0, *)
private struct StoredShow: Codable, Sendable {
    var id: String
    var bandName: String
    var year: Int
    var venue: String
    var day: String
    var date: String
    var startTime: String
    var endTime: String
    var eventType: String
    var sentence: String
}

@available(iOS 27.0, *)
private enum SiriCatalogFiles {
    private static let lock = NSLock()

    static var root: URL {
        FilePaths.directoryPath.appendingPathComponent("SiriCatalog", isDirectory: true)
    }

    static func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    static func prepare() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("csv", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bands", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("shows", isDirectory: true), withIntermediateDirectories: true)
    }

    static func loadCheckpoint() -> SiriCatalogCheckpoint {
        withLock {
            let url = root.appendingPathComponent("checkpoint.json")
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(SiriCatalogCheckpoint.self, from: data) else {
                return SiriCatalogCheckpoint()
            }
            return decoded
        }
    }

    static func saveCheckpoint(_ checkpoint: SiriCatalogCheckpoint) {
        withLock {
            let url = root.appendingPathComponent("checkpoint.json")
            guard let data = try? JSONEncoder().encode(checkpoint) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    static func csvURL(year: Int, kind: String) -> URL {
        root.appendingPathComponent("csv").appendingPathComponent("\(year)-\(kind).csv")
    }

    static func readCSV(year: Int, kind: String) -> Data? {
        withLock { try? Data(contentsOf: csvURL(year: year, kind: kind)) }
    }

    static func writeCSV(year: Int, kind: String, data: Data) {
        withLock {
            try? data.write(to: csvURL(year: year, kind: kind), options: .atomic)
        }
    }

    static func writeBands(_ bands: [StoredBand], year: Int) {
        writeJSON(bands, name: "bands/\(year).json")
    }

    static func writeShows(_ shows: [StoredShow], year: Int) {
        writeJSON(shows, name: "shows/\(year).json")
    }

    static func loadBands(year: Int) -> [StoredBand] {
        loadJSON("bands/\(year).json")
    }

    static func loadShows(year: Int) -> [StoredShow] {
        loadJSON("shows/\(year).json")
    }

    static func loadAllBands() -> [StoredBand] {
        loadAll(folder: "bands")
    }

    static func loadAllShows() -> [StoredShow] {
        loadAll(folder: "shows")
    }

    static func removeYearFiles(year: Int) {
        withLock {
            let files = [
                csvURL(year: year, kind: "artist"),
                csvURL(year: year, kind: "schedule"),
                root.appendingPathComponent("bands/\(year).json"),
                root.appendingPathComponent("shows/\(year).json")
            ]
            for url in files where FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private static func writeJSON<T: Encodable>(_ value: T, name: String) {
        withLock {
            let url = root.appendingPathComponent(name)
            guard let data = try? JSONEncoder().encode(value) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func loadJSON<T: Decodable>(_ name: String) -> [T] {
        withLock {
            let url = root.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url) else { return [] }
            return (try? JSONDecoder().decode([T].self, from: data)) ?? []
        }
    }

    private static func loadAll<T: Decodable>(folder: String) -> [T] {
        withLock {
            let dir = root.appendingPathComponent(folder, isDirectory: true)
            guard let names = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
                return []
            }
            var records: [T] = []
            for url in names where url.pathExtension == "json" {
                guard let data = try? Data(contentsOf: url),
                      let decoded = try? JSONDecoder().decode([T].self, from: data) else { continue }
                records.append(contentsOf: decoded)
            }
            return records
        }
    }
}

@available(iOS 27.0, *)
private enum SiriCatalogText {
    static func checksum(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func stableID(kind: String, year: Int, parts: [String]) -> String {
        let raw = parts.joined(separator: "\u{1f}")
        let digest = SHA256.hash(data: Data(raw.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(kind):\(year):\(digest)"
    }

    static func noteID(for bandName: String) -> String {
        let digest = SHA256.hash(data: Data(bandName.lowercased().utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return "band:\(digest)"
    }

    static func startOfYear(_ year: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 0)
    }

    static func spokenList(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + last
    }

    /// Accepts the CSV form (M/d/yyyy) and the database form (yyyy-MM-dd), 24-hour or AM/PM times.
    static func showDate(date: String, time: String) -> Date? {
        let date = date.trimmingCharacters(in: .whitespaces)
        let time = time.trimmingCharacters(in: .whitespaces)
        guard !date.isEmpty, !time.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let formats = [
            "M/d/yyyy H:mm", "M/d/yyyy h:mm a", "M/d/yyyy h:mma",
            "yyyy-MM-dd H:mm", "yyyy-MM-dd h:mm a", "yyyy-MM-dd h:mma"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: "\(date) \(time)") {
                return parsed
            }
        }
        return nil
    }

    static func festivalPhrase() -> String {
        let name = FestivalConfig.current.festivalName
        if FestivalConfig.current.festivalShortName == "70K" {
            return "\(name) cruise"
        }
        return name
    }

    static func aliases(for name: String) -> [String] {
        let stripped = name.replacingOccurrences(of: "-", with: "")
        guard stripped.caseInsensitiveCompare(name) != .orderedSame, !stripped.isEmpty else { return [] }
        return [stripped]
    }

    static func rows(in csv: String) -> [[String: String]] {
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else { return [] }
        let headers = splitFields(headerLine).map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.dropFirst().map { line in
            let fields = splitFields(line)
            var row: [String: String] = [:]
            for (index, header) in headers.enumerated() where !header.isEmpty && index < fields.count {
                row[header.lowercased()] = fields[index].trimmingCharacters(in: .whitespaces)
            }
            return row
        }
    }

    static func field(_ row: [String: String], _ name: String) -> String {
        row[name.lowercased()] ?? ""
    }

    static func splitFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for character in line {
            if character == "\"" {
                inQuotes.toggle()
                continue
            }
            if character == "," && !inQuotes {
                fields.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        fields.append(current)
        return fields
    }
}

/// One note per band covering every catalog year, so "what years did X play" is answered by a single record.
@available(iOS 27.0, *)
@AppEntity(schema: .notes.note)
struct FestivalBandEntity: IndexedEntity, Sendable {
    static let defaultQuery = FestivalBandEntityQuery()

    let id: String
    var name: String
    var content: String?
    var attachments: [IntentFile]
    var creationDate: Date?
    var modificationDate: Date?
    var folder: FestivalBandFolderEntity?
    var isPinned: Bool

    init(id: String, name: String, content: String, firstYear: Int, latestYear: Int) {
        self.id = id
        self.name = name
        self.content = content
        self.attachments = []
        self.creationDate = SiriCatalogText.startOfYear(firstYear)
        self.modificationDate = SiriCatalogText.startOfYear(latestYear)
        self.folder = nil
        self.isPinned = false
    }

    var displayRepresentation: DisplayRepresentation {
        let alias = SiriCatalogText.aliases(for: name)
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(SiriCatalogText.festivalPhrase())",
            synonyms: alias.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(itemContentType: "public.plain-text")
        set.title = name
        set.displayName = name
        set.contentDescription = content
        set.textContent = content
        set.keywords = [name, SiriCatalogText.festivalPhrase()] + SiriCatalogText.aliases(for: name)
        return set
    }
}

/// Required by the notes schema; band notes are never filed in a folder.
@available(iOS 27.0, *)
@AppEntity(schema: .notes.folder)
struct FestivalBandFolderEntity: Sendable {
    static let defaultQuery = FestivalBandFolderQuery()

    let id: String
    var name: String
    var account: FestivalBandAccountEntity?
    var parentFolder: FestivalBandFolderEntity?

    init(id: String) {
        self.id = id
        self.name = id
        self.account = nil
        self.parentFolder = nil
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(SiriCatalogText.festivalPhrase())")
    }
}

@available(iOS 27.0, *)
struct FestivalBandFolderQuery: EntityQuery {
    func entities(for identifiers: [FestivalBandFolderEntity.ID]) async throws -> [FestivalBandFolderEntity] { [] }
}

/// Required by the notes folder schema; never populated.
@available(iOS 27.0, *)
@AppEntity(schema: .notes.account)
struct FestivalBandAccountEntity: Sendable {
    static let defaultQuery = FestivalBandAccountQuery()

    let id: String
    var name: String

    init(id: String) {
        self.id = id
        self.name = id
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

@available(iOS 27.0, *)
struct FestivalBandAccountQuery: EntityQuery {
    func entities(for identifiers: [FestivalBandAccountEntity.ID]) async throws -> [FestivalBandAccountEntity] { [] }
}

@available(iOS 27.0, *)
struct FestivalBandEntityQuery: EntityStringQuery, IndexedEntityQuery {
    func entities(for identifiers: [FestivalBandEntity.ID]) async throws -> [FestivalBandEntity] {
        let wanted = Set(identifiers)
        return Self.allNotes().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [FestivalBandEntity] {
        let needle = Self.searchKey(string)
        guard !needle.isEmpty else { return [] }
        return Self.allNotes().filter { note in
            ([note.name] + SiriCatalogText.aliases(for: note.name)).contains { Self.searchKey($0).contains(needle) }
        }
    }

    /// Every catalog band; these become the band names in the App Shortcut phrases, so past bands match too.
    func suggestedEntities() async throws -> [FestivalBandEntity] {
        Self.allNotes()
    }

    func reindexEntities(for identifiers: [FestivalBandEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
        let found = try await entities(for: identifiers)
        if !found.isEmpty {
            try await CSSearchableIndex.default().indexAppEntities(found)
        }
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let all = Self.allNotes()
        if !all.isEmpty {
            try await CSSearchableIndex.default().indexAppEntities(all)
        }
    }

    private static func allNotes() -> [FestivalBandEntity] {
        SiriCatalogBuilder.bandNotes(from: SiriCatalogFiles.loadAllBands(), festival: SiriCatalogText.festivalPhrase())
    }

    private static func searchKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }
}

/// Lets Siri open a band from the catalog. Uses the same detail screen the attendance wizard opens.
@available(iOS 27.0, *)
struct OpenFestivalBandIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Band"
    static let description = IntentDescription("Shows a band's details.")

    @Parameter(title: "Band")
    var target: FestivalBandEntity

    init() {}

    init(target: FestivalBandEntity) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let bandName = target.name
        // A cold launch from Siri needs the band list screen to exist before it can present the detail.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationCenter.default.post(
                name: Notification.Name("AutoChooseAttendanceOpenBandDetail"),
                object: nil,
                userInfo: ["bandName": bandName]
            )
        }
        return .result()
    }
}

/// Speaks the band's festival history from the catalog note. Does not open the app.
@available(iOS 27.0, *)
struct FestivalBandHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Band History"
    static let description = IntentDescription("Tells how many times and in which years a band played the festival.")

    @Parameter(title: "Band", requestValueDialog: "Which band?")
    var band: FestivalBandEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = band.content ?? "\(band.name) is not in the \(SiriCatalogText.festivalPhrase()) lineup history."
        return .result(dialog: "\(answer)")
    }
}

/// Speaks a band's show times from the catalog events. Does not open the app.
@available(iOS 27.0, *)
struct FestivalShowTimesIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Times"
    static let description = IntentDescription("Tells when and where a band plays.")

    @Parameter(title: "Band", requestValueDialog: "Which band?")
    var band: FestivalBandEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = SiriCatalogBuilder.showTimesAnswer(bandName: band.name, festival: SiriCatalogText.festivalPhrase())
        return .result(dialog: "\(answer)")
    }
}

@available(iOS 27.0, *)
struct FestivalAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FestivalShowTimesIntent(),
            phrases: [
                "When does \(\.$band) play in \(.applicationName)",
                "When is \(\.$band) playing in \(.applicationName)",
                "\(\.$band) show times in \(.applicationName)",
                "Show times in \(.applicationName)"
            ],
            shortTitle: "Show Times",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: FestivalBandHistoryIntent(),
            phrases: [
                "How many times has \(\.$band) played \(.applicationName)",
                "What years did \(\.$band) play \(.applicationName)",
                "\(\.$band) history in \(.applicationName)",
                "Band history in \(.applicationName)"
            ],
            shortTitle: "Band History",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: OpenFestivalBandIntent(),
            phrases: [
                "Open \(\.$target) in \(.applicationName)",
                "Show \(\.$target) in \(.applicationName)",
                "Look up a band in \(.applicationName)"
            ],
            shortTitle: "Open Band",
            systemImageName: "music.mic"
        )
    }
}

/// One calendar event per scheduled show. Times are read in the device time zone, matching the app's alerts.
@available(iOS 27.0, *)
@AppEntity(schema: .calendar.event)
struct FestivalShowEntity: IndexedEntity, Sendable {
    static let defaultQuery = FestivalShowEntityQuery()

    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: FestivalShowLocation?
    var note: String?
    var calendar: FestivalScheduleCalendarEntity
    var status: FestivalShowStatus?
    var travelTime: Duration?
    var attendees: [FestivalShowAttendeeEntity]
    var organizers: [IntentPerson]
    var alarms: [FestivalShowAlarm]
    var recurrence: Calendar.RecurrenceRule?
    var virtualLocation: URL?

    /// Venue text kept outside the schema union so Spotlight and the subtitle can read it directly.
    private let venue: String

    init(id: String, title: String, startDate: Date, endDate: Date, venue: String, note: String) {
        self.id = id
        self.venue = venue
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = false
        self.location = venue.isEmpty ? nil : .text(venue)
        self.note = note
        self.calendar = FestivalScheduleCalendarEntity()
        self.status = .confirmed
        self.travelTime = nil
        self.attendees = []
        self.organizers = []
        self.alarms = []
        self.recurrence = nil
        self.virtualLocation = nil
    }

    var displayRepresentation: DisplayRepresentation {
        var subtitle = startDate.formatted(date: .abbreviated, time: .shortened)
        if !venue.isEmpty {
            subtitle += " · \(venue)"
        }
        let alias = SiriCatalogText.aliases(for: title)
        return DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(subtitle)",
            synonyms: alias.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(itemContentType: "public.calendar-event")
        set.title = title
        set.displayName = title
        set.contentDescription = note
        set.textContent = note
        set.startDate = startDate
        set.endDate = endDate
        set.namedLocation = venue
        set.keywords = [title, venue, SiriCatalogText.festivalPhrase()] + SiriCatalogText.aliases(for: title)
        return set
    }
}

@available(iOS 27.0, *)
@UnionValue
enum FestivalShowLocation {
    case place(PlaceDescriptor)
    case text(String)
}

@available(iOS 27.0, *)
@UnionValue
enum FestivalShowAlarm {
    case offset(Duration)
    case date(Date)
}

@available(iOS 27.0, *)
@AppEnum(schema: .calendar.eventStatus)
enum FestivalShowStatus: String {
    case confirmed
    case tentative
    case cancelled

    static let caseDisplayRepresentations: [FestivalShowStatus: DisplayRepresentation] = [
        .confirmed: "Confirmed",
        .tentative: "Tentative",
        .cancelled: "Cancelled"
    ]
}

/// The single calendar every festival show belongs to.
@available(iOS 27.0, *)
@AppEntity(schema: .calendar.calendar)
struct FestivalScheduleCalendarEntity: Sendable {
    static let defaultQuery = FestivalScheduleCalendarQuery()

    let id: String
    var title: String

    init() {
        id = "festival-schedule"
        title = "\(FestivalConfig.current.festivalName) Schedule"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

@available(iOS 27.0, *)
struct FestivalScheduleCalendarQuery: EntityQuery {
    func entities(for identifiers: [FestivalScheduleCalendarEntity.ID]) async throws -> [FestivalScheduleCalendarEntity] {
        let calendar = FestivalScheduleCalendarEntity()
        return identifiers.contains(calendar.id) ? [calendar] : []
    }
}

/// Required by the calendar schema; shows never list attendees.
@available(iOS 27.0, *)
@AppEntity(schema: .calendar.attendee)
struct FestivalShowAttendeeEntity: Sendable {
    static let defaultQuery = FestivalShowAttendeeQuery()

    let id: String
    var person: IntentPerson
    var status: FestivalAttendeeStatus?
    var type: FestivalAttendeeType?
    var isAttendanceOptional: Bool

    init(id: String, person: IntentPerson) {
        self.id = id
        self.person = person
        self.status = nil
        self.type = nil
        self.isAttendanceOptional = true
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

@available(iOS 27.0, *)
struct FestivalShowAttendeeQuery: EntityQuery {
    func entities(for identifiers: [FestivalShowAttendeeEntity.ID]) async throws -> [FestivalShowAttendeeEntity] { [] }
}

@available(iOS 27.0, *)
@AppEnum(schema: .calendar.attendeeStatus)
enum FestivalAttendeeStatus: String {
    case accepted
    case tentative
    case declined

    static let caseDisplayRepresentations: [FestivalAttendeeStatus: DisplayRepresentation] = [
        .accepted: "Accepted",
        .tentative: "Tentative",
        .declined: "Declined"
    ]
}

@available(iOS 27.0, *)
@AppEnum(schema: .calendar.attendeeType)
enum FestivalAttendeeType: String {
    case person

    static let caseDisplayRepresentations: [FestivalAttendeeType: DisplayRepresentation] = [
        .person: "Person"
    ]
}

@available(iOS 27.0, *)
struct FestivalShowEntityQuery: EntityQuery, IndexedEntityQuery {
    func entities(for identifiers: [FestivalShowEntity.ID]) async throws -> [FestivalShowEntity] {
        let wanted = Set(identifiers)
        return SiriCatalogFiles.loadAllShows().filter { wanted.contains($0.id) }.compactMap(Self.entity)
    }

    func suggestedEntities() async throws -> [FestivalShowEntity] { [] }

    func reindexEntities(for identifiers: [FestivalShowEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
        let found = try await entities(for: identifiers)
        if !found.isEmpty {
            try await CSSearchableIndex.default().indexAppEntities(found)
        }
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let all = SiriCatalogFiles.loadAllShows().compactMap(Self.entity)
        if !all.isEmpty {
            try await CSSearchableIndex.default().indexAppEntities(all)
        }
    }

    private static func entity(_ stored: StoredShow) -> FestivalShowEntity? {
        SiriCatalogBuilder.event(from: stored)
    }
}

@available(iOS 27.0, *)
private enum SiriCatalogBuilder {
    /// Nil when the start time cannot be read; the calendar schema requires real dates.
    static func event(from show: StoredShow) -> FestivalShowEntity? {
        guard let start = SiriCatalogText.showDate(date: show.date, time: show.startTime) else { return nil }
        var end = SiriCatalogText.showDate(date: show.date, time: show.endTime) ?? start.addingTimeInterval(60 * 60)
        if end <= start {
            end = end.addingTimeInterval(24 * 60 * 60)
        }
        var title = show.bandName
        if !show.eventType.isEmpty, show.eventType.caseInsensitiveCompare("Show") != .orderedSame {
            title += " (\(show.eventType))"
        }
        return FestivalShowEntity(id: show.id, title: title, startDate: start, endDate: end, venue: show.venue, note: show.sentence)
    }

    /// Uses the band's most recent scheduled year. Says so when the band is on a newer lineup without a schedule yet.
    static func showTimesAnswer(bandName: String, festival: String, now: Date = Date()) -> String {
        let key = bandName.lowercased()
        let events = SiriCatalogFiles.loadAllShows()
            .filter { $0.bandName.lowercased() == key }
            .compactMap { show in event(from: show).map { (show: show, event: $0) } }
        let lineupYear = SiriCatalogFiles.loadAllBands().filter { $0.name.lowercased() == key }.map(\.year).max()

        guard let scheduleYear = events.map(\.show.year).max() else {
            if let lineupYear {
                return "\(bandName) is on the \(lineupYear) \(festival) lineup, but no show times are listed yet."
            }
            return "\(bandName) has no shows on the \(festival) schedule."
        }

        let inYear = events.filter { $0.show.year == scheduleYear }.sorted { $0.event.startDate < $1.event.startDate }
        let parts = inYear.map { item -> String in
            let when = item.event.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
            var text = item.show.venue.isEmpty ? "on \(when)" : "at \(item.show.venue) on \(when)"
            if !item.show.eventType.isEmpty, item.show.eventType.caseInsensitiveCompare("Show") != .orderedSame {
                text += " (\(item.show.eventType))"
            }
            return text
        }
        let upcoming = inYear.contains { $0.event.endDate >= now }
        var answer = "In \(scheduleYear), \(bandName) \(upcoming ? "plays" : "played") \(SiriCatalogText.spokenList(parts))."
        if let lineupYear, lineupYear > scheduleYear {
            answer = "\(bandName) is on the \(lineupYear) lineup, but no show times are listed yet. " + answer
        }
        return answer
    }

    static func bandNotes(from bands: [StoredBand], festival: String) -> [FestivalBandEntity] {
        let groups = Dictionary(grouping: bands) { $0.name.lowercased() }
        return groups.values.compactMap { entries -> FestivalBandEntity? in
            let byYear = entries.sorted { $0.year < $1.year }
            guard let newest = byYear.last else { return nil }
            let name = newest.name
            let years = Array(Set(byYear.map(\.year))).sorted().map(String.init)
            let times = years.count == 1 ? "1 time" : "\(years.count) times"
            var content = "\(name) has played the \(festival) \(times), in \(SiriCatalogText.spokenList(years))."
            if let genre = byYear.last(where: { !$0.genre.isEmpty })?.genre {
                content += " Genre: \(genre)."
            }
            if let country = byYear.last(where: { !$0.country.isEmpty })?.country {
                content += " Country: \(country)."
            }
            let aliases = SiriCatalogText.aliases(for: name)
            if !aliases.isEmpty {
                content += " Also called \(aliases.joined(separator: ", "))."
            }
            return FestivalBandEntity(
                id: SiriCatalogText.noteID(for: name),
                name: name,
                content: content,
                firstYear: byYear.first?.year ?? newest.year,
                latestYear: newest.year
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func bands(year: Int, csv: String, festival: String) -> [StoredBand] {
        var seen: [String: StoredBand] = [:]
        for row in SiriCatalogText.rows(in: csv) {
            let name = SiriCatalogText.field(row, "bandName")
            guard !name.isEmpty else { continue }
            let genre = SiriCatalogText.field(row, "genre")
            let country = SiriCatalogText.field(row, "country")
            let prior = SiriCatalogText.field(row, "priorYears")
            var sentence = "\(name) played the \(festival) in \(year)."
            if !genre.isEmpty { sentence += " Genre: \(genre)." }
            if !country.isEmpty { sentence += " Country: \(country)." }
            if !prior.isEmpty, prior.caseInsensitiveCompare("Never") != .orderedSame {
                sentence += " Other listed years: \(prior)."
            }
            let aliases = SiriCatalogText.aliases(for: name)
            if !aliases.isEmpty {
                sentence += " Also called \(aliases.joined(separator: ", "))."
            }
            let id = SiriCatalogText.stableID(kind: "band", year: year, parts: [name])
            seen[name.lowercased()] = StoredBand(id: id, name: name, year: year, genre: genre, country: country, sentence: sentence)
        }
        return seen.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func shows(year: Int, csv: String, festival: String) -> [StoredShow] {
        var shows: [StoredShow] = []
        for row in SiriCatalogText.rows(in: csv) {
            let name = SiriCatalogText.field(row, "Band")
            guard !name.isEmpty else { continue }
            let venue = SiriCatalogText.field(row, "Location")
            let day = SiriCatalogText.field(row, "Day")
            let date = SiriCatalogText.field(row, "Date")
            let start = SiriCatalogText.field(row, "Start Time")
            let end = SiriCatalogText.field(row, "End Time")
            let eventType = SiriCatalogText.field(row, "Type")
            let notes = SiriCatalogText.field(row, "Notes")
            var sentence = "\(name) plays"
            if !venue.isEmpty { sentence += " at \(venue)" }
            if !day.isEmpty { sentence += " on \(day)" }
            if !date.isEmpty { sentence += " (\(date))" }
            if !start.isEmpty { sentence += " at \(start)" }
            if !end.isEmpty { sentence += " until \(end)" }
            sentence += " at the \(festival) in \(year)."
            if !eventType.isEmpty { sentence += " Event type: \(eventType)." }
            if !notes.isEmpty { sentence += " Notes: \(notes)." }
            let aliases = SiriCatalogText.aliases(for: name)
            if !aliases.isEmpty {
                sentence += " Also called \(aliases.joined(separator: ", "))."
            }
            let id = SiriCatalogText.stableID(kind: "show", year: year, parts: [name, venue, day, date, start, eventType])
            shows.append(StoredShow(
                id: id,
                bandName: name,
                year: year,
                venue: venue,
                day: day,
                date: date,
                startTime: start,
                endTime: end,
                eventType: eventType,
                sentence: sentence
            ))
        }
        return shows
    }

    static func bands(year: Int, records: [BandData], festival: String) -> [StoredBand] {
        let lineup = records.filter { $0.lineIndex != nil }
        var seen: [String: StoredBand] = [:]
        for record in lineup {
            let name = record.bandName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let genre = record.genre ?? ""
            let country = record.country ?? ""
            let prior = record.priorYears ?? ""
            var sentence = "\(name) played the \(festival) in \(year)."
            if !genre.isEmpty { sentence += " Genre: \(genre)." }
            if !country.isEmpty { sentence += " Country: \(country)." }
            if !prior.isEmpty, prior.caseInsensitiveCompare("Never") != .orderedSame {
                sentence += " Other listed years: \(prior)."
            }
            let aliases = SiriCatalogText.aliases(for: name)
            if !aliases.isEmpty {
                sentence += " Also called \(aliases.joined(separator: ", "))."
            }
            let id = SiriCatalogText.stableID(kind: "band", year: year, parts: [name])
            seen[name.lowercased()] = StoredBand(id: id, name: name, year: year, genre: genre, country: country, sentence: sentence)
        }
        return seen.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func shows(year: Int, records: [EventData], festival: String) -> [StoredShow] {
        var shows: [StoredShow] = []
        for record in records {
            let name = record.bandName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let venue = record.location
            let day = record.day ?? ""
            let date = record.date ?? ""
            let start = record.startTime ?? ""
            let end = record.endTime ?? ""
            let eventType = record.eventType ?? ""
            let notes = record.notes ?? ""
            var sentence = "\(name) plays"
            if !venue.isEmpty { sentence += " at \(venue)" }
            if !day.isEmpty { sentence += " on \(day)" }
            if !date.isEmpty { sentence += " (\(date))" }
            if !start.isEmpty { sentence += " at \(start)" }
            if !end.isEmpty { sentence += " until \(end)" }
            sentence += " at the \(festival) in \(year)."
            if !eventType.isEmpty { sentence += " Event type: \(eventType)." }
            if !notes.isEmpty { sentence += " Notes: \(notes)." }
            let aliases = SiriCatalogText.aliases(for: name)
            if !aliases.isEmpty {
                sentence += " Also called \(aliases.joined(separator: ", "))."
            }
            let id = SiriCatalogText.stableID(kind: "show", year: year, parts: [name, venue, day, date, start, eventType])
            shows.append(StoredShow(
                id: id,
                bandName: name,
                year: year,
                venue: venue,
                day: day,
                date: date,
                startTime: start,
                endTime: end,
                eventType: eventType,
                sentence: sentence
            ))
        }
        return shows
    }
}

private enum SiriCatalogHalt: Error {
    case indexingDisabled
}

@available(iOS 27.0, *)
private actor SiriCatalogJob {
    static let shared = SiriCatalogJob()

    private var running = false
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 90
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    static func kick() {
        Task.detached(priority: .utility) {
            await shared.run()
        }
    }

    private func run() async {
        if running { return }
        running = true
        defer { running = false }

        guard reportGate() else { return }
        guard FileManager.default.fileExists(atPath: FilePaths.cachedPointerFile) else {
            siriIndexNote("skip — pointer file is not on disk yet")
            return
        }

        let pointerText: String
        do {
            pointerText = try String(contentsOfFile: FilePaths.cachedPointerFile, encoding: .utf8)
        } catch {
            siriIndexNote("skip — could not read pointer file")
            return
        }

        let links = SiriCatalogPointer.years(in: pointerText)
        guard !links.isEmpty else {
            siriIndexNote("skip — pointer has no year band/schedule URLs")
            return
        }

        do {
            try SiriCatalogFiles.prepare()
        } catch {
            siriIndexNote("skip — could not create catalog folder")
            return
        }

        var checkpoint = SiriCatalogFiles.loadCheckpoint()
        let festival = SiriCatalogText.festivalPhrase()

        if checkpoint.format != SiriCatalogCheckpoint.currentFormat {
            guard await rebuildFromSavedFiles(festival: festival, checkpoint: &checkpoint) else { return }
        }

        let missing = links.filter { checkpoint.years[String($0.year)]?.indexed != true }

        if missing.isEmpty {
            siriIndexNote("catalog exists — updating current year from the database")
            var changed = await refreshCurrentYearFromDatabase(pointerText: pointerText, festival: festival, checkpoint: &checkpoint)
            if await removeYearsDroppedFromPointer(valid: Set(links.map(\.year)), checkpoint: &checkpoint) {
                changed = true
            }
            if changed {
                await refreshBandNotes(festival: festival, checkpoint: &checkpoint)
            }
            FestivalAppShortcuts.updateAppShortcutParameters()
            siriIndexNote("finished")
            return
        }

        siriIndexNote("first load — \(missing.count) years from CSV, skipping \(links.count - missing.count) already indexed")
        var fullPass = true

        for link in missing {
            if Task.isCancelled { return }
            guard SiriCatalogGate.allowsWork else {
                siriIndexNote("stop — Siri access turned off")
                return
            }
            do {
                let artist = try await bytes(for: link.artistURL, year: link.year, kind: "artist")
                let schedule = try await bytes(for: link.scheduleURL, year: link.year, kind: "schedule")
                let artistCSV = String(data: artist, encoding: .utf8) ?? ""
                let scheduleCSV = String(data: schedule, encoding: .utf8) ?? ""
                let bands = SiriCatalogBuilder.bands(year: link.year, csv: artistCSV, festival: festival)
                let shows = SiriCatalogBuilder.shows(year: link.year, csv: scheduleCSV, festival: festival)
                try await publish(
                    year: link.year,
                    bands: bands,
                    shows: shows,
                    entry: SiriCatalogCheckpointEntry(
                        artistURL: link.artistURL,
                        scheduleURL: link.scheduleURL,
                        artistChecksum: SiriCatalogText.checksum(artist),
                        scheduleChecksum: SiriCatalogText.checksum(schedule),
                        indexed: true
                    ),
                    checkpoint: &checkpoint
                )
                siriIndexNote("\(link.year) indexed from CSV — \(bands.count) bands, \(shows.count) shows")
            } catch SiriCatalogHalt.indexingDisabled {
                siriIndexNote("stop — index refused this app")
                return
            } catch {
                fullPass = false
                siriIndexNote("\(link.year) failed — will retry next launch (\(error.localizedDescription))")
            }
        }

        if fullPass {
            await removeYearsDroppedFromPointer(valid: Set(links.map(\.year)), checkpoint: &checkpoint)
        }
        await refreshBandNotes(festival: festival, checkpoint: &checkpoint)
        FestivalAppShortcuts.updateAppShortcutParameters()
        siriIndexNote("finished")
    }

    /// Reads the current festival year already stored by the app. Does not download.
    /// An empty read leaves the existing index in place so a launch that races the importer does not wipe it.
    /// Returns true when the year was re-donated.
    private func refreshCurrentYearFromDatabase(
        pointerText: String,
        festival: String,
        checkpoint: inout SiriCatalogCheckpoint
    ) async -> Bool {
        guard SiriCatalogGate.allowsWork else {
            siriIndexNote("stop — Siri access turned off")
            return false
        }
        guard let year = SiriCatalogPointer.currentYear(in: pointerText) else {
            siriIndexNote("skip database update — pointer has no current year")
            return false
        }
        guard checkpoint.years[String(year)]?.indexed == true else {
            siriIndexNote("skip database update — \(year) has no index yet")
            return false
        }

        let bandRecords = SQLiteDataManager.shared.fetchBands(forYear: year)
        let eventRecords = SQLiteDataManager.shared.fetchEvents(forYear: year)
        let bands = SiriCatalogBuilder.bands(year: year, records: bandRecords, festival: festival)
        let shows = SiriCatalogBuilder.shows(year: year, records: eventRecords, festival: festival)
        guard !bands.isEmpty, !shows.isEmpty else {
            siriIndexNote("\(year) database not ready — keeping existing index")
            return false
        }

        let bandChecksum = SiriCatalogText.checksum(Data(bands.map(\.sentence).sorted().joined(separator: "\n").utf8))
        let showChecksum = SiriCatalogText.checksum(Data(shows.map(\.sentence).sorted().joined(separator: "\n").utf8))
        if checkpoint.years[String(year)]?.isCurrent(
            artistURL: "sql",
            scheduleURL: "sql",
            artistChecksum: bandChecksum,
            scheduleChecksum: showChecksum
        ) == true {
            siriIndexNote("\(year) database unchanged")
            return false
        }

        do {
            try await publish(
                year: year,
                bands: bands,
                shows: shows,
                entry: SiriCatalogCheckpointEntry(
                    artistURL: "sql",
                    scheduleURL: "sql",
                    artistChecksum: bandChecksum,
                    scheduleChecksum: showChecksum,
                    indexed: true
                ),
                checkpoint: &checkpoint
            )
            siriIndexNote("\(year) updated from database — \(bands.count) bands, \(shows.count) shows")
            return true
        } catch SiriCatalogHalt.indexingDisabled {
            siriIndexNote("stop — index refused this app")
        } catch {
            siriIndexNote("\(year) database update failed — will retry next launch (\(error.localizedDescription))")
        }
        return false
    }

    /// Clears this app's index and re-donates every saved year in the current record shape. No downloads.
    private func rebuildFromSavedFiles(festival: String, checkpoint: inout SiriCatalogCheckpoint) async -> Bool {
        let years = checkpoint.years.filter { $0.value.indexed }.keys.compactMap(Int.init).sorted()
        siriIndexNote("record format changed — re-donating \(years.count) saved years")
        do {
            try await CSSearchableIndex.default().deleteAllSearchableItems()
            for year in years {
                let shows = SiriCatalogFiles.loadShows(year: year)
                try await donate(shows.compactMap(SiriCatalogBuilder.event(from:)), removing: [], as: FestivalShowEntity.self)
            }
        } catch SiriCatalogHalt.indexingDisabled {
            siriIndexNote("stop — index refused this app")
            return false
        } catch {
            siriIndexNote("rebuild failed — will retry next launch (\(error.localizedDescription))")
            return false
        }
        checkpoint.bandNoteIDs = []
        checkpoint.format = SiriCatalogCheckpoint.currentFormat
        await refreshBandNotes(festival: festival, checkpoint: &checkpoint)
        return true
    }

    /// Re-donates one note per band from every saved year. A failure forces a rebuild on the next launch.
    private func refreshBandNotes(festival: String, checkpoint: inout SiriCatalogCheckpoint) async {
        let notes = SiriCatalogBuilder.bandNotes(from: SiriCatalogFiles.loadAllBands(), festival: festival)
        let stale = Set(checkpoint.bandNoteIDs ?? []).subtracting(notes.map(\.id))
        do {
            try await donate(notes, removing: stale, as: FestivalBandEntity.self)
            checkpoint.bandNoteIDs = notes.map(\.id)
            siriIndexNote("band notes donated — \(notes.count) bands")
        } catch {
            checkpoint.format = nil
            siriIndexNote("band notes failed — will rebuild next launch (\(error.localizedDescription))")
        }
        SiriCatalogFiles.saveCheckpoint(checkpoint)
    }

    private func publish(
        year: Int,
        bands: [StoredBand],
        shows: [StoredShow],
        entry: SiriCatalogCheckpointEntry,
        checkpoint: inout SiriCatalogCheckpoint
    ) async throws {
        let oldShows = SiriCatalogFiles.loadShows(year: year)
        try await donate(
            shows.compactMap(SiriCatalogBuilder.event(from:)),
            removing: Set(oldShows.map(\.id)).subtracting(shows.map(\.id)),
            as: FestivalShowEntity.self
        )
        SiriCatalogFiles.writeBands(bands, year: year)
        SiriCatalogFiles.writeShows(shows, year: year)
        checkpoint.years[String(year)] = entry
        SiriCatalogFiles.saveCheckpoint(checkpoint)
    }

    private func reportGate() -> Bool {
        if !SiriCatalogGate.isNewSiriActive {
            siriIndexNote("skip — new Siri is not active")
            return false
        }
        if !SiriCatalogGate.isEnabledForThisApp {
            siriIndexNote("skip — Siri search is turned off for this app")
            return false
        }
        return true
    }

    private func bytes(for urlString: String, year: Int, kind: String) async throws -> Data {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http"), let url = URL(string: trimmed) {
            do {
                var request = URLRequest(url: url)
                request.setValue("70KBands-SiriCatalog", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty {
                    SiriCatalogFiles.writeCSV(year: year, kind: kind, data: data)
                    return data
                }
            } catch {
                if let cached = SiriCatalogFiles.readCSV(year: year, kind: kind), !cached.isEmpty {
                    return cached
                }
                throw error
            }
        }
        if let cached = SiriCatalogFiles.readCSV(year: year, kind: kind), !cached.isEmpty {
            return cached
        }
        throw URLError(.fileDoesNotExist)
    }

    private func donate<Entity: IndexedEntity>(
        _ entities: [Entity],
        removing stale: Set<Entity.ID>,
        as type: Entity.Type
    ) async throws {
        if !stale.isEmpty {
            try await delete(Array(stale), as: type)
        }
        var index = 0
        while index < entities.count {
            guard SiriCatalogGate.allowsWork else { throw SiriCatalogHalt.indexingDisabled }
            let end = min(index + 100, entities.count)
            do {
                try await CSSearchableIndex.default().indexAppEntities(Array(entities[index..<end]))
            } catch {
                if isIndexingRefusal(error) { throw SiriCatalogHalt.indexingDisabled }
                throw error
            }
            index = end
        }
    }

    private func delete<Entity: IndexedEntity>(_ identifiers: [Entity.ID], as type: Entity.Type) async throws {
        var index = 0
        while index < identifiers.count {
            let end = min(index + 100, identifiers.count)
            do {
                try await CSSearchableIndex.default().deleteAppEntities(identifiedBy: Array(identifiers[index..<end]), ofType: type)
            } catch {
                if isIndexingRefusal(error) { throw SiriCatalogHalt.indexingDisabled }
                throw error
            }
            index = end
        }
    }

    private func isIndexingRefusal(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == CSIndexErrorDomain && (ns.code == -1000 || ns.code == -1005)
    }

    /// Returns true when any year was removed; band notes need rebuilding afterwards.
    @discardableResult
    private func removeYearsDroppedFromPointer(valid: Set<Int>, checkpoint: inout SiriCatalogCheckpoint) async -> Bool {
        var removed = false
        let stored = checkpoint.years.keys.compactMap(Int.init)
        for year in stored where !valid.contains(year) {
            let shows = SiriCatalogFiles.loadShows(year: year).map(\.id)
            do {
                if !shows.isEmpty {
                    try await delete(shows, as: FestivalShowEntity.self)
                }
                SiriCatalogFiles.removeYearFiles(year: year)
                checkpoint.years.removeValue(forKey: String(year))
                SiriCatalogFiles.saveCheckpoint(checkpoint)
                siriIndexNote("removed \(year) — no longer in the pointer")
                removed = true
            } catch {
                siriIndexNote("could not remove \(year) (\(error.localizedDescription))")
            }
        }
        return removed
    }
}
