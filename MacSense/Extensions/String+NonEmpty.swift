import Foundation

extension String {
    /// Returns `nil` when the string is empty after trimming whitespace,
    /// otherwise returns the original. Useful for treating empty Info.plist
    /// entries as missing so a `??` fallback can kick in.
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
