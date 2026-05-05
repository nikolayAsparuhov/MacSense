import Foundation

/// One running process surfaced in the Process List modal.
struct SystemProcess: Identifiable, Hashable {
    let id: pid_t
    var pid: pid_t { id }
    let user: String
    let cpuPercent: Double
    let memoryPercent: Double
    let memoryBytes: Int64
    let name: String
    let fullCommand: String

    var displayName: String { name.isEmpty ? fullCommand : name }
}
