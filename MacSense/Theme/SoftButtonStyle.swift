import SwiftUI

/// Pill-shaped secondary button matching the glossy aesthetic. Replaces
/// the system bordered style everywhere — the system style renders an
/// accent-tinted (blue) border that fights the design.
struct SoftButtonStyle: ButtonStyle {
	var tint: Color = .primary
	var prominent: Bool = false

	func makeBody(configuration: Configuration) -> some View {
		SoftButtonBody(configuration: configuration, tint: tint, prominent: prominent)
	}
}

private struct SoftButtonBody: View {
	let configuration: ButtonStyle.Configuration
	let tint: Color
	let prominent: Bool
	@State private var hovering = false

	var body: some View {
		configuration.label
			.font(.system(size: 12, weight: .semibold))
			.padding(.horizontal, 12).padding(.vertical, 6)
			.foregroundStyle(prominent ? Color.white : tint)
			.background(
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.fill(fill)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.strokeBorder(stroke, lineWidth: 1)
			)
			.opacity(configuration.isPressed ? 0.85 : 1.0)
			.scaleEffect(configuration.isPressed ? 0.97 : 1.0)
			.animation(.spring(response: 0.2, dampingFraction: 0.85), value: configuration.isPressed)
			.animation(.easeInOut(duration: 0.12), value: hovering)
			.onHover { hovering = $0 }
			.contentShape(Rectangle())
	}

	private var fill: AnyShapeStyle {
		if prominent {
			return AnyShapeStyle(Theme.brandGradient)
		}
		return AnyShapeStyle(Color.white.opacity(hovering ? 0.10 : 0.06))
	}

	private var stroke: Color {
		prominent ? Color.white.opacity(0.18) : Color.white.opacity(hovering ? 0.18 : 0.10)
	}
}

extension ButtonStyle where Self == SoftButtonStyle {
	static var soft: SoftButtonStyle { SoftButtonStyle() }
	static func soft(tint: Color) -> SoftButtonStyle { SoftButtonStyle(tint: tint) }
	static var softProminent: SoftButtonStyle { SoftButtonStyle(prominent: true) }
}
