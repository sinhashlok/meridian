/// Widely used zone abbreviations (decision B, docs/decisions.md).
///
/// Foundation's `TimeZone.abbreviation` depends on the device locale, so London can come
/// back as `GMT+1`. This table makes labels the same on every device. Zones not listed
/// show their offset only (`UTC+5:45`), which is never ambiguous.
///
/// Left out on purpose: China (CST clashes with US Central), Dublin (Irish "standard"
/// time is the summer one, so Foundation's DST flag is inverted), and zones with no
/// abbreviation people actually use.
enum ZoneAbbreviations {
    /// Zone id → (standard, daylight). Zones without DST repeat the standard one.
    static let table: [String: (standard: String, daylight: String)] = [
        // Europe
        "Europe/London": ("GMT", "BST"),
        "Europe/Lisbon": ("WET", "WEST"),
        "Europe/Paris": ("CET", "CEST"),
        "Europe/Berlin": ("CET", "CEST"),
        "Europe/Amsterdam": ("CET", "CEST"),
        "Europe/Brussels": ("CET", "CEST"),
        "Europe/Madrid": ("CET", "CEST"),
        "Europe/Rome": ("CET", "CEST"),
        "Europe/Zurich": ("CET", "CEST"),
        "Europe/Vienna": ("CET", "CEST"),
        "Europe/Stockholm": ("CET", "CEST"),
        "Europe/Oslo": ("CET", "CEST"),
        "Europe/Copenhagen": ("CET", "CEST"),
        "Europe/Warsaw": ("CET", "CEST"),
        "Europe/Prague": ("CET", "CEST"),
        "Europe/Athens": ("EET", "EEST"),
        "Europe/Helsinki": ("EET", "EEST"),
        "Europe/Bucharest": ("EET", "EEST"),
        // Americas
        "America/New_York": ("EST", "EDT"),
        "America/Toronto": ("EST", "EDT"),
        "America/Chicago": ("CST", "CDT"),
        "America/Denver": ("MST", "MDT"),
        "America/Phoenix": ("MST", "MST"),
        "America/Los_Angeles": ("PST", "PDT"),
        "America/Vancouver": ("PST", "PDT"),
        "America/Anchorage": ("AKST", "AKDT"),
        "Pacific/Honolulu": ("HST", "HST"),
        // Asia
        "Asia/Kolkata": ("IST", "IST"),
        "Asia/Calcutta": ("IST", "IST"),
        "Asia/Tokyo": ("JST", "JST"),
        "Asia/Seoul": ("KST", "KST"),
        "Asia/Singapore": ("SGT", "SGT"),
        "Asia/Hong_Kong": ("HKT", "HKT"),
        "Asia/Jakarta": ("WIB", "WIB"),
        // Oceania
        "Australia/Sydney": ("AEST", "AEDT"),
        "Australia/Melbourne": ("AEST", "AEDT"),
        "Australia/Brisbane": ("AEST", "AEST"),
        "Australia/Adelaide": ("ACST", "ACDT"),
        "Australia/Perth": ("AWST", "AWST"),
        "Pacific/Auckland": ("NZST", "NZDT"),
        // Africa
        "Africa/Johannesburg": ("SAST", "SAST"),
    ]

    static func abbreviation(for zoneID: String, isDaylightSaving: Bool) -> String? {
        table[zoneID].map { isDaylightSaving ? $0.daylight : $0.standard }
    }
}
