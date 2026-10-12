import Foundation

struct AppRelease: Equatable, Sendable {
    var version: String
    var pageURL: URL
    var downloadURL: URL
}

enum UpdateCheckOutcome: Equatable, Sendable {
    case upToDate(current: String)
    case available(AppRelease)
    case noRelease
    case failed
}

enum AppUpdate {
    static let repository = "hgrafa/ai-usage-widget"
    static let diskImageName = "AI-Usage.dmg"
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    static func currentVersion(bundle: Bundle = .main) -> String {
        let raw = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return normalize(raw ?? "0.0.0")
    }

    static func normalize(_ version: String) -> String {
        var value = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }
        return value
    }

    /// Numeric dotted versions. A longer release is newer when the shared prefix matches (`0.1.1` > `0.1`).
    static func isNewer(_ remote: String, than local: String) -> Bool {
        compare(remote, local) == .orderedDescending
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(lhs)
        let right = components(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    static func release(from data: Data) -> AppRelease? {
        guard let object = JSONFields.decodeObject(data),
              let tag = JSONFields.string(object["tag_name"]),
              let page = JSONFields.string(object["html_url"]).flatMap(URL.init(string:))
        else { return nil }

        let assets = object["assets"] as? [[String: Any]] ?? []
        let downloads: [(name: String, url: URL)] = assets.compactMap { asset in
            guard let name = JSONFields.string(asset["name"]),
                  let url = JSONFields.string(asset["browser_download_url"]).flatMap(URL.init(string:))
            else { return nil }
            return (name, url)
        }
        let dmg = downloads.first { $0.name == diskImageName }?.url
            ?? downloads.first { $0.name.lowercased().hasSuffix(".dmg") }?.url

        return AppRelease(version: normalize(tag), pageURL: page, downloadURL: dmg ?? page)
    }

    private static func components(_ version: String) -> [Int] {
        normalize(version).split(separator: ".").map { part in
            Int(part) ?? 0
        }
    }
}

enum UpdateChecker {
    static func check(current: String, client: any HTTPClient = URLSessionHTTPClient()) async -> UpdateCheckOutcome {
        var request = URLRequest(url: AppUpdate.latestReleaseURL)
        request.setValue("AIUsageWidget", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let response = try await client.send(request)
            if response.statusCode == 404 {
                return .noRelease
            }
            guard (200..<300).contains(response.statusCode),
                  let release = AppUpdate.release(from: response.body)
            else { return .failed }
            if AppUpdate.isNewer(release.version, than: current) {
                return .available(release)
            }
            return .upToDate(current: AppUpdate.normalize(current))
        } catch {
            return .failed
        }
    }
}
