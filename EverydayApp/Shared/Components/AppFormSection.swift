import SwiftUI

struct AppFormSection<Content: View>: View {
    let title: String
    let description: String?
    let content: Content

    @Environment(\.appTheme) private var theme

    init(title: String, description: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(title.uppercased())
                .font(theme.typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(theme.colors.secondary)

            if let description {
                Text(description)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary.opacity(0.8))
            }

            VStack(spacing: theme.spacing.small) {
                content
            }
            .padding(theme.spacing.medium)
            .frame(maxWidth: .infinity)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.medium, style: .continuous))
            .shadow(color: theme.colors.primary.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    AppFormSection(title: "Quick Add", description: "Create a list entry to track later.") {
        TextField("Title", text: .constant(""))
            .textFieldStyle(.roundedBorder)
        PrimaryButton(title: "Save") {}
    }
    .padding()
    .environment(\.appTheme, .default)
    .background(AppColor.background)
}
