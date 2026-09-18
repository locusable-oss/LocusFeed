import Foundation

/// What LocusFeed does once the store is open. Applied on the next launch, not when the picker changes.
enum LaunchBehavior: String, CaseIterable, Identifiable, Sendable {
    case openOnly
    case refreshOnLaunch
    case focusFirstUnread

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openOnly: return "Open only"
        case .refreshOnLaunch: return "Refresh all feeds"
        case .focusFirstUnread: return "Jump to first unread"
        }
    }

    static func resolve(_ raw: String?) -> LaunchBehavior {
        guard let raw, let value = LaunchBehavior(rawValue: raw) else { return .openOnly }
        return value
    }
}

/// Article body size. Titles stay at the system title style so the hierarchy does not collapse.
enum BodyFontSize: String, CaseIterable, Identifiable, Sendable {
    case small
    case regular
    case large
    case extraLarge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .regular: return "Regular"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    /// Point size shared by plain text, attributed HTML, and the sandboxed web view.
    var points: Double {
        switch self {
        case .small: return 13
        case .regular: return 16
        case .large: return 18
        case .extraLarge: return 22
        }
    }

    static func resolve(_ raw: String?) -> BodyFontSize {
        guard let raw, let value = BodyFontSize(rawValue: raw) else { return .regular }
        return value
    }
}

/// UserDefaults-backed preferences shared by AppState and Settings UI.
enum AppSettings {
    static let refreshIntervalMinutesKey = "refreshIntervalMinutes"
    static let launchBehaviorKey = "launchBehavior"
    static let bodyFontSizeKey = "bodyFontSize"

    /// Minutes between automatic refreshes. `0` disables the timer.
    static var refreshIntervalMinutes: Int {
        get {
            if UserDefaults.standard.object(forKey: refreshIntervalMinutesKey) == nil {
                return 0
            }
            return max(0, UserDefaults.standard.integer(forKey: refreshIntervalMinutesKey))
        }
        set {
            UserDefaults.standard.set(max(0, newValue), forKey: refreshIntervalMinutesKey)
        }
    }

    static var launchBehavior: LaunchBehavior {
        get { LaunchBehavior.resolve(UserDefaults.standard.string(forKey: launchBehaviorKey)) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: launchBehaviorKey) }
    }

    static var bodyFontSize: BodyFontSize {
        get { BodyFontSize.resolve(UserDefaults.standard.string(forKey: bodyFontSizeKey)) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: bodyFontSizeKey) }
    }

    static let intervalChoices: [(label: String, minutes: Int)] = [
        ("Off", 0),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("1 hour", 60),
        ("2 hours", 120),
        ("6 hours", 360),
    ]
}
