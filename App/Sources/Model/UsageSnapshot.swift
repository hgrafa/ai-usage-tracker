import Foundation

struct UsageSnapshot: Equatable, Sendable {
    var provider: ProviderID
    var fetchedAt: Date
    var meters: [Meter]
    var breakdown: Breakdown?
    var menuBarFraction: Double?
    /// Informational copy when the account has no meter to draw, such as a missing Grok allowance.
    var note: String?
    /// Claude's saved free limit resets. Nil means the account was not checked.
    var resets: ResetInventory?
    /// Prepaid credits, extra usage, and banked limit resets. Nil until Claude usage has been read.
    var extras: ClaudeAccountExtras?
    /// Where the numbers came from, when that is worth saying, such as a Claude Code login.
    var source: String?

    init(
        provider: ProviderID,
        fetchedAt: Date,
        meters: [Meter],
        breakdown: Breakdown? = nil,
        menuBarFraction: Double? = nil,
        note: String? = nil,
        resets: ResetInventory? = nil,
        extras: ClaudeAccountExtras? = nil
    ) {
        self.provider = provider
        self.fetchedAt = fetchedAt
        self.meters = meters
        self.breakdown = breakdown
        self.menuBarFraction = menuBarFraction
        self.note = note
        self.resets = resets
        self.extras = extras
    }
}

struct ClaudeAccountExtras: Equatable, Sendable {
    var currency: String = "USD"
    var freeCreditsMinor: Int = 0
    var spentMinor: Int = 0
    var limitMinor: Int = 0
    var extraResetsAt: Date?
    var limitResetsLeft: Int = 0
    var limitResetsEndAt: Date?
    var fableActive: Bool = false

    var showsCreditSection: Bool { spentMinor > 0 || freeCreditsMinor > 0 }

    func money(_ minor: Int) -> String {
        let value = Double(minor) / 100
        if currency == "USD" {
            return String(format: "$%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        return String(format: "%@ %.2f", locale: Locale(identifier: "en_US_POSIX"), currency, value)
    }

    var extraCaption: String {
        let percent = limitMinor > 0 ? Double(spentMinor) / Double(limitMinor) : 0
        let percentInt = Int((percent * 100).rounded())
        let percentLabel = percentInt > 100 ? "over limit" : "\(percentInt)%"
        if limitMinor > 0 {
            return "\(money(spentMinor)) of \(money(limitMinor)) · \(percentLabel)"
        }
        return "\(money(spentMinor)) spent"
    }

    var extraFraction: Double? {
        guard spentMinor > 0, limitMinor > 0 else { return nil }
        return min(1, Double(spentMinor) / Double(limitMinor))
    }

    var extraResetCaption: String? {
        guard let extraResetsAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Resets \(formatter.string(from: extraResetsAt))"
    }

    var limitResetCaption: String? {
        guard limitResetsLeft > 0 else { return nil }
        let count = limitResetsLeft
        let until = limitResetsEndAt.map { date in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return " until \(formatter.string(from: date.addingTimeInterval(-1)))"
        } ?? ""
        return "\(count) usage-limit reset\(count == 1 ? "" : "s") available\(until)"
    }

    /// Shown when there is no banked reset. Hidden once both Fable and extra usage are active.
    var reassurance: String? {
        if limitResetsLeft > 0 { return nil }
        if fableActive && showsCreditSection { return nil }
        if !fableActive && !showsCreditSection { return "No Fable or extra usage" }
        if !showsCreditSection { return "No extra usage" }
        return "No Fable usage"
    }
}

struct LimitReset: Identifiable, Equatable, Sendable {
    var id: String
    var remaining: Int
    var restores: String
    var expiresAt: Date?
    var available: Bool

    func caption(now: Date) -> String {
        if !available {
            if let expiresAt {
                return "Free reset unavailable until \(UsageFormatting.deadline(expiresAt))"
            }
            return "Free reset unavailable"
        }
        let count = remaining == 1 ? "1 free reset" : "\(remaining) free resets"
        var caption = "\(count) · restores \(restores)"
        if let expiresAt {
            caption += " · use by \(UsageFormatting.deadline(expiresAt))"
        }
        return caption
    }
}

enum ResetInventory: Equatable, Sendable {
    case none
    case grants([LimitReset])
}
