import SwiftUI

enum FluxoTheme {
    static let background = Color(red: 0.96, green: 0.98, blue: 0.96)
    static let cardBackground = Color.white
    static let primary = Color(red: 0.09, green: 0.76, blue: 0.34)
    static let primaryPressed = Color(red: 0.06, green: 0.65, blue: 0.29)
    static let primaryTextOnButton = Color.white
    static let titleText = Color(red: 0.07, green: 0.09, blue: 0.08)
    static let secondaryText = Color(red: 0.36, green: 0.40, blue: 0.37)
    static let border = Color(red: 0.86, green: 0.89, blue: 0.86)
    static let error = Color(red: 0.82, green: 0.20, blue: 0.18)
}

struct CardContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(FluxoTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FluxoTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func fluxoCardContainer() -> some View {
        modifier(CardContainerModifier())
    }
}
