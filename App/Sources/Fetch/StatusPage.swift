import Foundation

enum ServiceLevel: Equatable, Sendable {
    case operational
    case degraded
    case partial
    case major
    case unknown

    var word: String {
        switch self {
        case .operational: "Clear"
        case .degraded: "Degraded"
        case .partial: "Disrupted"
        case .major: "Down"
        case .unknown: "Unknown"
        }
    }

    /// Clear and unknown stay off the row. A lamp only appears when the service is in trouble.
    var reportsTrouble: Bool {
        switch self {
        case .degraded, .partial, .major: true
        case .operational, .unknown: false
        }
    }
}

struct ServiceComponent: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var level: ServiceLevel
    var statusLabel: String
}

struct ServiceHealth: Equatable, Sendable {
    var level: ServiceLevel
    var title: String
    var affected: [String]
    var components: [ServiceComponent]
    var pageURL: URL

    var detail: String {
        guard !affected.isEmpty else { return title }
        return "\(title). Affects \(affected.joined(separator: ", "))"
    }

    static func unavailable(pageURL: URL) -> ServiceHealth {
        ServiceHealth(
            level: .unknown,
            title: "Status unavailable",
            affected: [],
            components: [],
            pageURL: pageURL
        )
    }
}

enum StatusPages {
    static let claudeSummary = URL(string: "https://status.claude.com/api/v2/summary.json")!
    static let openaiComponents = URL(string: "https://status.openai.com/api/v2/components.json")!
    static let cursorSummary = URL(string: "https://status.cursor.com/api/v2/summary.json")!
    static let claudePage = URL(string: "https://status.claude.com")!
    static let openaiPage = URL(string: "https://status.openai.com")!
    static let cursorPage = URL(string: "https://status.cursor.com")!
}

enum StatusPageMapping {
    static func claude(from data: Data) -> ServiceHealth? {
        guard let object = JSONFields.decodeObject(data) else { return nil }
        let components = components(in: object["components"])
        guard !components.isEmpty || JSONFields.dictionary(object["status"]) != nil else { return nil }
        let page = JSONFields.dictionary(object["status"])
        let level = level(forIndicator: JSONFields.string(page?["indicator"])) ?? worst(of: components)
        let title = JSONFields.string(page?["description"]) ?? title(for: level)
        return ServiceHealth(
            level: level,
            title: title,
            affected: affectedNames(in: components),
            components: components,
            pageURL: StatusPages.claudePage
        )
    }

    static func codex(from data: Data) -> ServiceHealth? {
        let components = components(in: componentList(data)).filter {
            $0.name.range(of: "codex", options: .caseInsensitive) != nil
        }
        guard !components.isEmpty else { return nil }
        return rolledUp(components, pageURL: StatusPages.openaiPage)
    }

    static func cursorAndGrok(from data: Data) -> (cursor: ServiceHealth, grok: ServiceHealth)? {
        guard let object = JSONFields.decodeObject(data) else { return nil }
        let components = components(in: object["components"])
        guard !components.isEmpty else { return nil }
        let grokComponents = components.filter { $0.name.caseInsensitiveCompare("Grok Bot") == .orderedSame }
        let cursorComponents = components.filter { $0.name.caseInsensitiveCompare("Grok Bot") != .orderedSame }
        let grok = grokComponents.isEmpty
            ? ServiceHealth.unavailable(pageURL: StatusPages.cursorPage)
            : rolledUp(grokComponents, pageURL: StatusPages.cursorPage)
        let cursor = cursorComponents.isEmpty
            ? ServiceHealth.unavailable(pageURL: StatusPages.cursorPage)
            : rolledUp(cursorComponents, pageURL: StatusPages.cursorPage)
        return (cursor, grok)
    }

    private static func rolledUp(_ components: [ServiceComponent], pageURL: URL) -> ServiceHealth {
        let level = worst(of: components)
        return ServiceHealth(
            level: level,
            title: title(for: level),
            affected: affectedNames(in: components),
            components: components,
            pageURL: pageURL
        )
    }

    private static func componentList(_ data: Data) -> Any? {
        if let object = JSONFields.decodeObject(data) {
            return object["components"]
        }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func components(in value: Any?) -> [ServiceComponent] {
        guard let items = value as? [Any] else { return [] }
        var components: [ServiceComponent] = []
        for item in items {
            guard let object = item as? [String: Any] else { continue }
            if JSONFields.bool(object["group"]) == true { continue }
            guard let name = JSONFields.string(object["name"]),
                  let status = JSONFields.string(object["status"])
            else { continue }
            let id = JSONFields.string(object["id"]) ?? name
            components.append(ServiceComponent(
                id: id,
                name: shortName(name),
                level: level(forStatus: status),
                statusLabel: statusLabel(status)
            ))
        }
        return components
    }

    private static func shortName(_ name: String) -> String {
        guard let range = name.range(of: " (") else { return name }
        return String(name[..<range.lowerBound])
    }

    private static func affectedNames(in components: [ServiceComponent]) -> [String] {
        components.filter { $0.level != .operational && $0.level != .unknown }.map(\.name)
    }

    private static func worst(of components: [ServiceComponent]) -> ServiceLevel {
        components.map(\.level).max(by: { rank($0) < rank($1) }) ?? .unknown
    }

    private static func rank(_ level: ServiceLevel) -> Int {
        switch level {
        case .operational: 0
        case .unknown: 1
        case .degraded: 2
        case .partial: 3
        case .major: 4
        }
    }

    private static func title(for level: ServiceLevel) -> String {
        switch level {
        case .operational: "All Systems Operational"
        case .degraded: "Degraded Performance"
        case .partial: "Partial Outage"
        case .major: "Major Outage"
        case .unknown: "Status unavailable"
        }
    }

    private static func level(forIndicator indicator: String?) -> ServiceLevel? {
        switch indicator {
        case "none": .operational
        case "minor": .degraded
        case "major": .partial
        case "critical": .major
        default: nil
        }
    }

    private static func level(forStatus status: String) -> ServiceLevel {
        switch status {
        case "operational": .operational
        case "degraded_performance", "under_maintenance": .degraded
        case "partial_outage": .partial
        case "major_outage": .major
        default: .unknown
        }
    }

    private static func statusLabel(_ status: String) -> String {
        switch status {
        case "operational": "Operational"
        case "degraded_performance": "Degraded"
        case "partial_outage": "Partial outage"
        case "major_outage": "Major outage"
        case "under_maintenance": "Maintenance"
        default: status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

struct StatusPageFetcher: Sendable {
    var http: any HTTPClient = URLSessionHTTPClient()

    func fetch() async -> [ProviderID: ServiceHealth] {
        async let claudeBody = load(StatusPages.claudeSummary)
        async let openaiBody = load(StatusPages.openaiComponents)
        async let cursorBody = load(StatusPages.cursorSummary)

        var health: [ProviderID: ServiceHealth] = [:]
        if let data = await claudeBody, let mapped = StatusPageMapping.claude(from: data) {
            health[.claude] = mapped
        } else {
            health[.claude] = .unavailable(pageURL: StatusPages.claudePage)
        }
        // status.claude.com also covers the Claude API and Console.
        health[.anthropic] = health[.claude]
        if let data = await openaiBody, let mapped = StatusPageMapping.codex(from: data) {
            health[.codex] = mapped
        } else {
            health[.codex] = .unavailable(pageURL: StatusPages.openaiPage)
        }
        if let data = await cursorBody, let mapped = StatusPageMapping.cursorAndGrok(from: data) {
            health[.cursor] = mapped.cursor
            health[.grok] = mapped.grok
        } else {
            health[.cursor] = .unavailable(pageURL: StatusPages.cursorPage)
            health[.grok] = .unavailable(pageURL: StatusPages.cursorPage)
        }
        return health
    }

    private func load(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(ClaudeRequests.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let response = try await http.send(request)
            guard (200..<300).contains(response.statusCode) else { return nil }
            return response.body
        } catch {
            return nil
        }
    }
}
