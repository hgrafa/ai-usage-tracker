import Foundation

/// Finds a command-line tool the way a login shell would. Menu-bar apps do not
/// inherit a login shell PATH, so official install spots under the home folder
/// and Homebrew are checked after PATH.
enum CommandLocator {
    static func resolve(
        command: String,
        homeRelativePaths: [String],
        fallbacks: [String],
        pathEnvironment: String?,
        homeDirectory: String?,
        isExecutable: (String) -> Bool
    ) -> URL? {
        if let pathEnvironment {
            for directory in pathEnvironment.split(separator: ":") where !directory.isEmpty {
                let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(command).path
                if isExecutable(candidate) {
                    return URL(fileURLWithPath: candidate)
                }
            }
        }
        if let homeDirectory, !homeDirectory.isEmpty {
            for relative in homeRelativePaths {
                let candidate = URL(fileURLWithPath: homeDirectory).appendingPathComponent(relative).path
                if isExecutable(candidate) {
                    return URL(fileURLWithPath: candidate)
                }
            }
        }
        for candidate in fallbacks where isExecutable(candidate) {
            return URL(fileURLWithPath: candidate)
        }
        return nil
    }
}
