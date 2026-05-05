import Foundation
import Darwin

/// Snapshot listing of running processes via `ps`. Cheap (~10ms on a
/// typical Mac) so the modal can refresh on a 2s timer for live data.
enum ProcessLister {
    /// Returns all processes sorted by CPU% descending.
    static func list() -> [SystemProcess] {
        // ps -axww -o pid=,user=,pcpu=,pmem=,rss=,command=
        // The trailing `command` field contains spaces (executable
        // path + arguments), so we treat it as "everything after the
        // first 5 whitespace-separated fields" rather than splitting
        // on space across the whole line. `-w -w` widens the output
        // so command isn't truncated.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axww", "-o", "pid=,user=,pcpu=,pmem=,rss=,command="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let raw = String(data: data, encoding: .utf8) ?? ""

        var out: [SystemProcess] = []
        out.reserveCapacity(512)
        for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Walk character by character to slice off exactly 5
            // whitespace-separated tokens, then keep the remainder
            // verbatim — that remainder is the full command, paths
            // and spaces intact.
            var fields: [String] = []
            var current = ""
            var idx = trimmed.startIndex
            let end = trimmed.endIndex
            while idx < end && fields.count < 5 {
                let ch = trimmed[idx]
                if ch == " " || ch == "\t" {
                    if !current.isEmpty {
                        fields.append(current)
                        current = ""
                    }
                } else {
                    current.append(ch)
                }
                idx = trimmed.index(after: idx)
            }
            // Skip the run of whitespace separating the 5th field from
            // the command remainder.
            while idx < end, trimmed[idx] == " " || trimmed[idx] == "\t" {
                idx = trimmed.index(after: idx)
            }
            // The 5th field is sitting in `current` if we stopped at
            // its end without hitting whitespace.
            if fields.count == 4 && !current.isEmpty {
                fields.append(current)
            }
            guard fields.count == 5 else { continue }
            let fullCommand = String(trimmed[idx...])
            guard !fullCommand.isEmpty else { continue }

            guard let pid = pid_t(fields[0]) else { continue }
            let user = fields[1]
            let pcpu = Double(fields[2]) ?? 0
            let pmem = Double(fields[3]) ?? 0
            let rssKB = Int64(fields[4]) ?? 0

            // Derive a short, human-friendly name from the command:
            //   /Applications/Xcode.app/Contents/MacOS/Xcode -psn_…
            //     → "Xcode"
            //   /usr/sbin/cfprefsd agent
            //     → "cfprefsd"
            //   -zsh
            //     → "zsh"
            let firstToken = fullCommand.split(separator: " ", maxSplits: 1).first.map(String.init) ?? fullCommand
            var shortName = (firstToken as NSString).lastPathComponent
            // Strip leading dash on login-shell entries like "-zsh".
            if shortName.hasPrefix("-") {
                shortName = String(shortName.dropFirst())
            }
            // Prefer the .app bundle name when the binary is buried
            // inside `<App>.app/Contents/MacOS/<Helper>`.
            if let appName = enclosingAppName(in: firstToken) {
                shortName = appName
            }

            out.append(SystemProcess(
                id: pid,
                user: user,
                cpuPercent: pcpu,
                memoryPercent: pmem,
                memoryBytes: rssKB * 1024,
                name: shortName,
                fullCommand: fullCommand
            ))
        }
        return out.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    /// Pulls the `.app` bundle name out of an executable path so
    /// `/Applications/Visual Studio Code.app/Contents/MacOS/Electron`
    /// renders as "Visual Studio Code" instead of "Electron".
    private static func enclosingAppName(in path: String) -> String? {
        guard let range = path.range(of: ".app/", options: .backwards) else { return nil }
        let beforeApp = path[..<range.lowerBound]
        let bundleStem = (String(beforeApp) as NSString).lastPathComponent
        return bundleStem.isEmpty ? nil : bundleStem
    }

    /// Send SIGTERM to a PID. Returns true on success. SIGKILL is left
    /// to the user (we don't escalate automatically).
    static func terminate(_ pid: pid_t) -> Bool {
        let result = kill(pid, SIGTERM)
        return result == 0
    }

    /// Send SIGKILL — last-resort force-quit when SIGTERM is ignored.
    /// Requires sudo for processes owned by another user; that case is
    /// surfaced as a returned `false`.
    static func forceKill(_ pid: pid_t) -> Bool {
        let result = kill(pid, SIGKILL)
        return result == 0
    }
}
