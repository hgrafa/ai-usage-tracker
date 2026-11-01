import Foundation

enum MeterHeat: Equatable, Sendable {
    case low
    case warm
    case hot

    static func level(for fraction: Double) -> MeterHeat {
        if fraction >= 0.90 { return .hot }
        if fraction >= 0.70 { return .warm }
        return .low
    }
}

enum UsageFormatting {
    static func clampedFraction(percent: Double) -> Double {
        min(1, max(0, percent / 100))
    }

    static func usedCaption(percent: Double, resetsAt: Date?, now: Date) -> String {
        var caption = "\(Int(percent.rounded()))% used"
        if let resetsAt {
            caption += " · \(resetHint(resetsAt, now: now))"
        }
        return caption
    }

    static func deadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func resetHint(_ date: Date, now: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = Calendar.current.isDate(date, inSameDayAs: now) ? .none : .short
        return "resets \(formatter.string(from: date))"
    }

    static func dollars(cents: Double) -> String {
        money(cents / 100)
    }

    static func money(_ amount: Double, currency: String = "USD") -> String {
        let formatted = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), amount)
        switch currency.uppercased() {
        case "USD": return "$\(formatted)"
        case "CNY": return "¥\(formatted)"
        default: return "\(currency.uppercased()) \(formatted)"
        }
    }

    static func parseISO8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: string)
    }
}
