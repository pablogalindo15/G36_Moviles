import SwiftUI

struct FluxoPrimaryButtonStyle: ButtonStyle {
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(FluxoTheme.primaryTextOnButton)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isDisabled ? 0.55 : 1)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isDisabled { return FluxoTheme.primary }
        return isPressed ? FluxoTheme.primaryPressed : FluxoTheme.primary
    }
}
