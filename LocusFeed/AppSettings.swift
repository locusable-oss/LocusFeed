import Foundation

/// UserDefaults-backed preferences shared by AppState and Settings UI.
enum AppSettings {
    static let refreshIntervalMinutesKey = "refreshIntervalMinutes"

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

    static let intervalChoices: [(label: String, minutes: Int)] = [
        ("Off", 0),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("1 hour", 60),
        ("2 hours", 120),
        ("6 hours", 360),
    ]
}
