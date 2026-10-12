import Foundation

/// Talks to `codex app-server` over stdin/stdout. Does not read or refresh ~/.codex/auth.json.
struct CodexAppServerClient: Sendable {
    static let missingCLIMessage = "Install the Codex CLI and run codex login."
    static let notLoggedInMessage = "Codex is not logged in. Run codex login in Terminal."

    static let requests = """
    {"method":"initialize","id":0,"params":{"clientInfo":{"name":"ai-usage-widget","title":"AI Usage","version":"0.1.0"}}}
    {"method":"initialized","params":{}}
    {"method":"account/rateLimits/read","id":1,"params":{}}

    """

    func rateLimitsResult() async throws -> Data {
        guard let executable = CodexExecutable.resolve(
            pathEnvironment: ProcessInfo.processInfo.environment["PATH"],
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) }
        ) else {
            throw UsageFetchError.message(Self.missingCLIMessage)
        }
        return try await Task.detached {
            try Self.run(executable: executable)
        }.value
    }

    private static func run(executable: URL) throws -> Data {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server"]
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        let collector = ByteCollector()
        let outHandle = output.fileHandleForReading
        let errHandle = errors.fileHandleForReading
        outHandle.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { collector.append(chunk) }
        }
        errHandle.readabilityHandler = { handle in
            _ = handle.availableData
        }
        defer {
            outHandle.readabilityHandler = nil
            errHandle.readabilityHandler = nil
            try? input.fileHandleForWriting.close()
            BlockingProcess.stop(process)
        }
        do {
            try process.run()
            try input.fileHandleForWriting.write(contentsOf: Data(requests.utf8))
        } catch {
            throw UsageFetchError.message(notLoggedInMessage)
        }

        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let buffer = collector.copy()
            if CodexStdoutParser.sawFailure(in: buffer) {
                throw UsageFetchError.message(notLoggedInMessage)
            }
            if let result = CodexStdoutParser.successResult(in: buffer) {
                return result
            }
            if !process.isRunning { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        let buffer = collector.copy()
        if let result = CodexStdoutParser.successResult(in: buffer) {
            return result
        }
        throw UsageFetchError.message(notLoggedInMessage)
    }
}

struct CodexUsageFetcher: UsageFetcher {
    var client: CodexAppServerClient = CodexAppServerClient()
    var now: @Sendable () -> Date = { Date() }

    func fetch() async throws -> UsageSnapshot {
        let result = try await client.rateLimitsResult()
        return try CodexUsageMapping.snapshot(from: result, fetchedAt: now())
    }
}
