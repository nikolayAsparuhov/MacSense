import SwiftUI

// MARK: - Bytes

/// Animated byte-count display. Smoothly tweens from the previous value to
/// the current one, matching the count-up feel CleanMyMac uses when a
/// scan completes ("0 GB" → "12.4 GB"). Use anywhere a size number could
/// change abruptly between states.
struct RollingByteCount: View, Animatable {
    var value: Double
    var font: Font = .system(size: 24, weight: .bold, design: .rounded)
    var foreground: AnyShapeStyle = AnyShapeStyle(Color.primary)

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(ByteCountFormatter.string(fromByteCount: Int64(max(0, value)), countStyle: .file))
            .font(font)
            .foregroundStyle(foreground)
            .monospacedDigit()
    }
}

extension View {
    /// Wraps `RollingByteCount` with the standard MacSense value animation
    /// so call sites stay one line.
    func rollingByteCount(_ value: Int64,
                          font: Font = .system(size: 24, weight: .bold, design: .rounded),
                          foreground: AnyShapeStyle = AnyShapeStyle(Color.primary)) -> some View {
        RollingByteCount(value: Double(value), font: font, foreground: foreground)
            .animation(AppAnimation.value, value: value)
    }
}

// MARK: - Percent

/// Tween a 0.0–1.0 value as an integer percent. Used by Performance gauges
/// so "47%" rolls smoothly between samples instead of snapping.
struct RollingPercent: View, Animatable {
    var value: Double
    var font: Font = .system(size: 24, weight: .bold, design: .rounded)
    var foreground: AnyShapeStyle = AnyShapeStyle(Color.primary)

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int((max(0, min(1, value)) * 100).rounded()))%")
            .font(font)
            .foregroundStyle(foreground)
            .monospacedDigit()
    }
}

extension View {
    func rollingPercent(_ value: Double,
                        font: Font = .system(size: 24, weight: .bold, design: .rounded),
                        foreground: AnyShapeStyle = AnyShapeStyle(Color.primary)) -> some View {
        RollingPercent(value: value, font: font, foreground: foreground)
            .animation(AppAnimation.value, value: value)
    }
}

// MARK: - Throughput rate

/// Animated bytes-per-second readout. Same idea, different formatter.
struct RollingRate: View, Animatable {
    var value: Double
    var font: Font = .system(size: 22, weight: .bold, design: .rounded)
    var foreground: AnyShapeStyle = AnyShapeStyle(Color.primary)

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Self.format(value) + "/s")
            .font(font)
            .foregroundStyle(foreground)
            .monospacedDigit()
    }

    /// `ByteCountFormatter`'s default returns "Zero KB" for 0, which reads
    /// awkwardly as a network rate. Disabling `allowsNonnumericFormatting`
    /// renders "0 bytes" instead.
    private static func format(_ value: Double) -> String {
        let bytes = Int64(max(0, value))
        let f = ByteCountFormatter()
        f.countStyle = .binary
        f.allowsNonnumericFormatting = false
        return f.string(fromByteCount: bytes)
    }
}

extension View {
    func rollingRate(_ value: Int64,
                     font: Font = .system(size: 22, weight: .bold, design: .rounded),
                     foreground: AnyShapeStyle = AnyShapeStyle(Color.primary)) -> some View {
        RollingRate(value: Double(value), font: font, foreground: foreground)
            .animation(AppAnimation.value, value: value)
    }
}
