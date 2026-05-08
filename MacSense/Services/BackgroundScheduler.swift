import Foundation

/// Wraps `NSBackgroundActivityScheduler` for the cleanup schedule.
///
/// Spec originally called for `BGTaskScheduler`, but that API is
/// iOS / Mac Catalyst only — on plain macOS the equivalent is
/// `NSBackgroundActivityScheduler`. Shape of the contract stays the
/// same: register a handler, submit a cadence, cancel when the user
/// disables the schedule. The scheduler runs only while the app is
/// alive — same constraint we already document in the Schedule UI.
enum BackgroundScheduler {
    static let cleanupTaskIdentifier = "tech.veraio.macsense.cleanup-scan"

    private static var current: NSBackgroundActivityScheduler?
    private static var handler: ((BGTaskShim) -> Void)?

    /// Wire up once during app launch. The handler closes over the
    /// AppDelegate's weak `AppState` reference and reads it on demand
    /// at fire time.
    static func register(handler: @escaping (BGTaskShim) -> Void) {
        Self.handler = handler
    }

    /// (Re)start the recurring activity. Cancels any previous
    /// instance so a cadence change immediately replaces the old
    /// schedule. `repeats = true` means the OS keeps firing at the
    /// chosen interval — no manual re-submit per run.
    static func submit(cadence: ScheduleCadence) {
        cancel()
        let scheduler = NSBackgroundActivityScheduler(identifier: cleanupTaskIdentifier)
        scheduler.repeats = true
        scheduler.interval = cadence.interval
        scheduler.tolerance = max(cadence.interval * 0.1, 60)
        scheduler.qualityOfService = .background
        current = scheduler
        scheduler.schedule { completion in
            let shim = BGTaskShim(completion: completion)
            DispatchQueue.main.async {
                if let handler = Self.handler {
                    handler(shim)
                } else {
                    completion(.deferred)
                }
            }
        }
        Logger.shared.log("Scheduled cleanup activity \(cadence.label) interval=\(Int(cadence.interval))s", level: .info)
    }

    static func cancel() {
        current?.invalidate()
        current = nil
    }
}

/// Thin shim so callers (`AppState`) don't depend on the
/// `NSBackgroundActivityScheduler` type. Forwards the only call the
/// worker needs — completing the activity with success / defer.
struct BGTaskShim {
    private let completion: (NSBackgroundActivityScheduler.Result) -> Void

    init(completion: @escaping (NSBackgroundActivityScheduler.Result) -> Void) {
        self.completion = completion
    }

    /// Kept for source-level parity with the original BGTask shape;
    /// `NSBackgroundActivityScheduler` doesn't expose an expiration
    /// callback, so this is a no-op on macOS.
    var onExpire: (() -> Void)? {
        get { nil }
        nonmutating set { _ = newValue }
    }

    func complete(success: Bool) {
        completion(success ? .finished : .deferred)
    }
}
