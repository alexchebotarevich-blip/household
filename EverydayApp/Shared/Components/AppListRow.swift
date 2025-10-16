import SwiftUI

struct AppListRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Content

    @Environment(\.appTheme) private var theme

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
                Text(title)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.secondary)
                }
            }

            Spacer()
            trailing
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondary)
        }
        .padding(.horizontal, theme.spacing.medium)
        .padding(.vertical, theme.spacing.small)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.small, style: .continuous))
        .shadow(color: theme.colors.primary.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    AppListRow(title: "Grocery run", subtitle: "Due tonight") {
        Image(systemName: "chevron.right")
    }
    .padding()
    .environment(\.appTheme, .default)
    .background(AppColor.background)
}
