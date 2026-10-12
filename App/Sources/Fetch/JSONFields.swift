import Foundation

enum JSONFields {
    static func decodeObject(_ data: Data) -> [String: Any]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return json as? [String: Any]
    }

    static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    static func bool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber else { return nil }
        guard CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    static func string(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func date(from value: Any?, milliseconds: Bool = false) -> Date? {
        if let number = double(value) {
            let seconds = milliseconds || number > 100_000_000_000 ? number / 1000 : number
            return Date(timeIntervalSince1970: seconds)
        }
        if let string = value as? String {
            if let number = Double(string) {
                return date(from: number, milliseconds: milliseconds)
            }
            return UsageFormatting.parseISO8601(string)
        }
        return nil
    }
}
