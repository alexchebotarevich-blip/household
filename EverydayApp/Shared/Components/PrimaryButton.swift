import SwiftUI

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.small) {
                if let icon {
                    Image(systemName: icon)
                }

                Text(title)
                    .font(theme.typography.callout)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, theme.spacing.small)
            .padding(.horizontal, theme.spacing.large)
            .background(theme.colors.primary)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    PrimaryButton(title: "Add Item", icon: "plus") {}
        .padding()
        .environment(\.appTheme, .default)
        .previewLayout(.sizeThatFits)
}
