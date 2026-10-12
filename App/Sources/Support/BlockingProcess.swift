import Darwin
import Foundation

final class ByteCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func copy() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

enum BlockingProcess {
    struct Output: Sendable {
        var status: Int32
        var stdout: Data
        var timedOut: Bool
    }

    static func run(executable: URL, arguments: [String], timeout: TimeInterval) -> Output {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let output = Pipe()
        let errors = Pipe()
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
        }
        do {
            try process.run()
        } catch {
            return Output(status: 1, stdout: Data(), timedOut: false)
        }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        let timedOut = process.isRunning
        stop(process)
        return Output(status: process.terminationStatus, stdout: collector.copy(), timedOut: timedOut)
    }

    static func stop(_ process: Process) {
        if process.isRunning {
            process.terminate()
        }
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning, process.processIdentifier > 0 {
            kill(process.processIdentifier, SIGKILL)
        }
        if process.processIdentifier > 0 {
            process.waitUntilExit()
        }
    }
}
