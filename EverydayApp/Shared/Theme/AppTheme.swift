import SwiftUI
import CoreGraphics

struct AppTheme {
    struct Palette {
        let primary: Color
        let secondary: Color
        let background: Color
        let surface: Color
        let accent: Color
    }

    struct Spacing {
        let xSmall: CGFloat
        let small: CGFloat
        let medium: CGFloat
        let large: CGFloat
        let xLarge: CGFloat
    }

    struct Typography {
        let largeTitle: Font
        let title: Font
        let subtitle: Font
        let body: Font
        let callout: Font
        let caption: Font
    }

    let colors: Palette
    let spacing: Spacing
    let typography: Typography

    static let `default` = AppTheme(
        colors: .init(
            primary: AppColor.primary,
            secondary: AppColor.secondary,
            background: AppColor.background,
            surface: AppColor.surface,
            accent: AppColor.accent
        ),
        spacing: .init(
            xSmall: AppSpacing.xSmall,
            small: AppSpacing.small,
            medium: AppSpacing.medium,
            large: AppSpacing.large,
            xLarge: AppSpacing.xLarge
        ),
        typography: .init(
            largeTitle: AppTypography.default.fonts.largeTitle,
            title: AppTypography.default.fonts.title,
            subtitle: AppTypography.default.fonts.subtitle,
            body: AppTypography.default.fonts.body,
            callout: AppTypography.default.fonts.callout,
            caption: AppTypography.default.fonts.caption
        )
    )
}
