import Foundation

/// Shared by the app and its three Screen Time extensions through the app
/// group. Holds the windows the app scheduled, which of them are open right
/// now, the protection mode, and the journal the shield writes. The chosen
/// apps live here too, as opaque tokens: nobody, including us, learns what
/// they are (docs/SOFT-GATE.md, iOS).
public enum GateShared {
    public static let appGroup = "group.com.stanchion.guard"
    public static let storeName = "guard"

    /// DeviceActivity refuses intervals under fifteen minutes, so a short
    /// window is monitored from fifteen minutes before it closes. The card
    /// shows the true open time; the shield may simply arrive early.
    public static let minimumIntervalSeconds: TimeInterval = 15 * 60

    /// Usage thresholds for "View for 60 seconds". Each event re-applies the
    /// shield after another minute of use, so a window allows five views.
    public static let viewEventSeconds: [Int] = [60, 120, 180, 240, 300]

    public struct Window: Codable, Equatable {
        public var windowId: String
        public var opensAtMs: Int64
        public var closesAtMs: Int64
        public var instrument: String
        public var events: String

        public init(windowId: String, opensAtMs: Int64, closesAtMs: Int64, instrument: String, events: String) {
            self.windowId = windowId
            self.opensAtMs = opensAtMs
            self.closesAtMs = closesAtMs
            self.instrument = instrument
            self.events = events
        }
    }

    public struct JournalEntry: Codable {
        public var windowId: String
        public var outcome: String
        public var atMs: Int64
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    private enum Key {
        static let windows = "windows"
        static let active = "activeWindowIds"
        static let protection = "protection"
        static let journal = "journal"
        static let selection = "selection"
    }

    public static var windows: [Window] {
        get { decode([Window].self, Key.windows) ?? [] }
        set { encode(newValue, Key.windows) }
    }

    public static var activeWindowIds: [String] {
        get { defaults.stringArray(forKey: Key.active) ?? [] }
        set { defaults.set(newValue, forKey: Key.active) }
    }

    public static var protection: String {
        get { defaults.string(forKey: Key.protection) ?? "soft-gate" }
        set { defaults.set(newValue, forKey: Key.protection) }
    }

    /// The encoded FamilyActivitySelection. Kept as Data here so this file
    /// needs no FamilyControls import and compiles anywhere.
    public static var selectionData: Data? {
        get { defaults.data(forKey: Key.selection) }
        set { defaults.set(newValue, forKey: Key.selection) }
    }

    public static func window(withId id: String) -> Window? {
        windows.first { $0.windowId == id }
    }

    /// The open window with the latest close, which is what the card describes.
    public static func currentWindow(now: Date = Date()) -> Window? {
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        let active = Set(activeWindowIds)
        let open = windows.filter { active.contains($0.windowId) || ($0.opensAtMs <= ms && ms < $0.closesAtMs) }
        return open.max { $0.closesAtMs < $1.closesAtMs }
    }

    public static func appendJournal(windowId: String, outcome: String, at: Date = Date()) {
        var entries = decode([JournalEntry].self, Key.journal) ?? []
        entries.append(JournalEntry(windowId: windowId, outcome: outcome, atMs: Int64(at.timeIntervalSince1970 * 1000)))
        if entries.count > 200 { entries.removeFirst(entries.count - 200) }
        encode(entries, Key.journal)
    }

    public static func drainJournal() -> [JournalEntry] {
        let entries = decode([JournalEntry].self, Key.journal) ?? []
        defaults.removeObject(forKey: Key.journal)
        return entries
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
