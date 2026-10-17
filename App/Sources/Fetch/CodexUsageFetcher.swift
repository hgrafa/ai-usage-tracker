import Foundation

enum CodexExecutable {
    static let fallbacks = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex"]

    static func resolve(
        pathEnvironment: String?,
        homeDirectory: String? = nil,
        isExecutable: (String) -> Bool
    ) -> URL? {
        CommandLocator.resolve(
            command: "codex",
            homeRelativePaths: [".local/bin/codex"],
            fallbacks: fallbacks,
            pathEnvironment: pathEnvironment,
            homeDirectory: homeDirectory,
            isExecutable: isExecutable
        )
    }
}

enum CodexStdoutParser {
    static func successResult(in buffer: Data) -> Data? {
        for object in objects(in: buffer) {
            guard jsonInt(object["id"]) == 1 else { continue }
            if object["error"] != nil { return nil }
            guard let result = object["result"], !(result is NSNull) else { continue }
            return try? JSONSerialization.data(withJSONObject: result)
        }
        return nil
    }

    static func sawFailure(in buffer: Data) -> Bool {
        for object in objects(in: buffer) {
            if jsonInt(object["id"]) == 1, object["error"] != nil {
                return true
            }
        }
        return false
    }

    private static func objects(in buffer: Data) -> [[String: Any]] {
        guard let text = String(data: buffer, encoding: .utf8) else { return [] }
        var objects: [[String: Any]] = []
        for line in text.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            objects.append(object)
        }
        return objects
    }

    private static func jsonInt(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            return number.intValue
        case let int as Int:
            return int
        default:
            return nil
        }
    }
}

enum CodexUsageMapping {
    static func windowTitle(minutes: Int?) -> String {
        switch minutes {
        case 300: "Session (5 hour)"
        case 10080: "Weekly (7 day)"
        case let value?: "Window (\(value) min)"
        case nil: "Usage"
        }
    }

    static func snapshot(from result: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let root = JSONFields.decodeObject(result) else {
            throw UsageFetchError.malformed
        }
        let limits: [String: Any]?
        if let byID = root["rateLimitsByLimitId"] as? [String: Any],
           let codex = byID["codex"] as? [String: Any] {
            limits = codex
        } else if let rateLimits = root["rateLimits"] as? [String: Any] {
            limits = rateLimits
        } else {
            limits = nil
        }
        guard let limits else { throw UsageFetchError.malformed }

        var meters: [Meter] = []
        var percents: [Double] = []
        for key in ["primary", "secondary"] {
            if limits[key] == nil || limits[key] is NSNull { continue }
            guard let window = limits[key] as? [String: Any],
                  let used = JSONFields.double(window["usedPercent"])
            else { continue }
            let minutes = JSONFields.double(window["windowDurationMins"]).map { Int($0) }
            percents.append(used)
            meters.append(Meter(
                id: key,
                title: windowTitle(minutes: minutes),
                fraction: UsageFormatting.clampedFraction(percent: used),
                caption: UsageFormatting.usedCaption(
                    percent: used,
                    resetsAt: JSONFields.date(from: window["resetsAt"]),
                    now: fetchedAt
                )
            ))
        }
        return UsageSnapshot(
            provider: .codex,
            fetchedAt: fetchedAt,
            meters: meters,
            breakdown: nil,
            menuBarFraction: percents.max().map { UsageFormatting.clampedFraction(percent: $0) }
        )
    }
}
