import SwiftUI

struct LoadingOverlay: View {
    let title: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressView()
                Text(title)
                    .font(.footnote)
                    .foregroundColor(FluxoTheme.secondaryText)
            }
            .padding(18)
            .fluxoCardContainer()
        }
    }
}
