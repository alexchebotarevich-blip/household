import SwiftUI

struct AppTypography {
    struct FontSet {
        let largeTitle: Font
        let title: Font
        let subtitle: Font
        let body: Font
        let callout: Font
        let caption: Font
    }

    let fonts: FontSet

    static let `default` = AppTypography(fonts: .init(
        largeTitle: .system(.largeTitle, design: .rounded).weight(.bold),
        title: .system(.title, design: .rounded).weight(.semibold),
        subtitle: .system(.title3, design: .rounded).weight(.medium),
        body: .system(.body, design: .rounded),
        callout: .system(.callout, design: .rounded),
        caption: .system(.caption, design: .rounded)
    ))
}
