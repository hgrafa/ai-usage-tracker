import Foundation

enum ClaudeExecutable {
    static let fallbacks = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude"]

    /// The native installer uses ~/.local/bin. Older npm "local" installs live in ~/.claude/local.
    static func resolve(
        pathEnvironment: String?,
        homeDirectory: String?,
        isExecutable: (String) -> Bool
    ) -> URL? {
        CommandLocator.resolve(
            command: "claude",
            homeRelativePaths: [".local/bin/claude", ".claude/local/claude"],
            fallbacks: fallbacks,
            pathEnvironment: pathEnvironment,
            homeDirectory: homeDirectory,
            isExecutable: isExecutable
        )
    }
}

/// What Claude Code's `get_usage` answer says about the signed-in account.
enum ClaudeCodeRead: Equatable, Sendable {
    /// The plan's rate-limit windows, as the usage endpoint returned them.
    case usage(Data)
    /// Signed in with a plan, but the CLI could not reach Claude for the numbers.
    case unanswered
    /// Plan limits do not apply: an API key, Console login, or third-party provider.
    case noPlanLimits
    case signedOut
    /// No CLI, an old CLI without `get_usage`, a crash, or a timeout.
    case unavailable
}

/// Speaks Claude Code's stream-json control protocol, the one the Agent SDK uses.
/// The widget never sends a prompt, so no model request is made and no tokens are spent.
enum ClaudeCodeProtocol {
    static let initializeID = "ai-usage-initialize"
    static let usageID = "ai-usage-get-usage"

    /// Print mode reading control requests from stdin. Settings sources are empty so the
    /// user's hooks do not run on every refresh; MCP servers and session files stay off too.
    static let arguments = [
        "-p",
        "--output-format", "stream-json",
        "--verbose",
        "--input-format", "stream-json",
        "--strict-mcp-config",
        "--no-session-persistence",
        "--setting-sources", ""
    ]

    static let initializeLine = line(id: initializeID, request: ["subtype": "initialize"])
    /// `skip_behaviors` skips the scan of a week of local transcripts that only the /usage dialog needs.
    static let usageLine = line(id: usageID, request: ["subtype": "get_usage", "skip_behaviors": true])

    enum Reply: Equatable {
        case success(Data)
        case failure
    }

    static func reply(to id: String, in buffer: Data) -> Reply? {
        guard let text = String(data: buffer, encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            guard let object = JSONFields.decodeObject(Data(line.utf8)),
                  JSONFields.string(object["type"]) == "control_response",
                  let response = JSONFields.dictionary(object["response"]),
                  JSONFields.string(response["request_id"]) == id
            else { continue }
            guard JSONFields.string(response["subtype"]) == "success" else { return .failure }
            let body = response["response"].flatMap { try? JSONSerialization.data(withJSONObject: $0) } ?? Data("{}".utf8)
            return .success(body)
        }
        return nil
    }

    static func read(usage: Data) -> ClaudeCodeRead {
        guard let object = JSONFields.decodeObject(usage),
              let available = JSONFields.bool(object["rate_limits_available"])
        else { return .unavailable }
        guard available else { return .noPlanLimits }
        guard let limits = JSONFields.dictionary(object["rate_limits"]),
              hasWindow(limits),
              let data = try? JSONSerialization.data(withJSONObject: limits)
        else { return .unanswered }
        return .usage(data)
    }

    static func isLoggedIn(authStatus: Data) -> Bool? {
        JSONFields.decodeObject(authStatus).flatMap { JSONFields.bool($0["loggedIn"]) }
    }

    private static func hasWindow(_ limits: [String: Any]) -> Bool {
        for key in ["five_hour", "seven_day"] where JSONFields.dictionary(limits[key]) != nil {
            return true
        }
        return !((limits["limits"] as? [Any]) ?? []).isEmpty
    }

    private static func line(id: String, request: [String: Any]) -> Data {
        let envelope: [String: Any] = ["type": "control_request", "request_id": id, "request": request]
        var data = (try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])) ?? Data()
        data.append(0x0A)
        return data
    }
}

/// Asks the `claude` CLI for plan usage the way T3 Code and the Agent SDK do: start it in
/// stream-json mode, initialize, send `get_usage`, and stop it. Claude Code reads its own
/// Keychain login and refreshes it, so the widget never handles that token here.
struct ClaudeCodeClient: Sendable {
    var locate: @Sendable () -> URL? = {
        let environment = ProcessInfo.processInfo.environment
        return ClaudeExecutable.resolve(
            pathEnvironment: environment["PATH"],
            homeDirectory: environment["HOME"] ?? NSHomeDirectory(),
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) }
        )
    }
    var timeout: TimeInterval = 20

    func read() async -> ClaudeCodeRead {
        guard let executable = locate() else { return .unavailable }
        let timeout = self.timeout
        return await Task.detached {
            let read = Self.run(executable: executable, timeout: timeout)
            guard read == .noPlanLimits else { return read }
            return Self.isSignedIn(executable: executable) ? .noPlanLimits : .signedOut
        }.value
    }

    private static func run(executable: URL, timeout: TimeInterval) -> ClaudeCodeRead {
        let process = Process()
        process.executableURL = executable
        process.arguments = ClaudeCodeProtocol.arguments
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        // A CLI that already quit must not take the app down with SIGPIPE when we write to it.
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
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
            try input.fileHandleForWriting.write(contentsOf: ClaudeCodeProtocol.initializeLine)
        } catch {
            return .unavailable
        }

        var askedForUsage = false
        var exitedAt: Date?
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exitedAt == nil, !process.isRunning { exitedAt = Date() }
            let buffer = collector.copy()
            if !askedForUsage {
                switch ClaudeCodeProtocol.reply(to: ClaudeCodeProtocol.initializeID, in: buffer) {
                case .success:
                    guard (try? input.fileHandleForWriting.write(contentsOf: ClaudeCodeProtocol.usageLine)) != nil else {
                        return .unavailable
                    }
                    askedForUsage = true
                case .failure:
                    return .unavailable
                case nil:
                    break
                }
            } else if let reply = ClaudeCodeProtocol.reply(to: ClaudeCodeProtocol.usageID, in: buffer) {
                guard case .success(let body) = reply else { return .unavailable }
                return ClaudeCodeProtocol.read(usage: body)
            }
            // Give the pipe a moment to drain what the CLI wrote just before it quit.
            if let exitedAt, Date().timeIntervalSince(exitedAt) > 0.5 { break }
            Thread.sleep(forTimeInterval: 0.03)
        }
        return .unavailable
    }

    /// `get_usage` says the same thing for an API-key login and for nobody signed in.
    private static func isSignedIn(executable: URL) -> Bool {
        let output = BlockingProcess.run(executable: executable, arguments: ["auth", "status", "--json"], timeout: 10)
        guard !output.timedOut else { return false }
        return ClaudeCodeProtocol.isLoggedIn(authStatus: output.stdout) == true
    }
}
