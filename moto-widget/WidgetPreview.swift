import SwiftUI

extension RGBAColor {
    init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

struct WidgetPreview: View {
    enum Size: String, CaseIterable, Identifiable {
        case small = "Small", medium = "Medium", large = "Large"
        case lockRectangular = "Lock", lockCircular = "Circle"

        var id: String { rawValue }

        var dimensions: CGSize {
            switch self {
            case .small: CGSize(width: 158, height: 158)
            case .medium: CGSize(width: 338, height: 158)
            case .large: CGSize(width: 338, height: 354)
            case .lockRectangular: CGSize(width: 160, height: 72)
            case .lockCircular: CGSize(width: 76, height: 76)
            }
        }

        var lockSlot: LockScreenSlot? {
            switch self {
            case .lockRectangular: .rectangular
            case .lockCircular: .circular
            default: nil
            }
        }
    }

    let text: String
    let profile: StyleProfile
    var size: Size = .small

    var body: some View {
        if let slot = size.lockSlot {
            StyledTextView(text: text, profile: profile, slot: slot)
                .frame(width: size.dimensions.width, height: size.dimensions.height)
                .background(.white.opacity(0.15))
                .clipShape(slot == .circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
                .padding(12)
                .background(.black, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .environment(\.colorScheme, .dark)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Lock Screen widget preview: \(text)")
        } else {
            homeScreenBody
        }
    }

    private var homeScreenBody: some View {
        StyledTextView(text: text, profile: profile)
            .padding(16)
            .frame(width: size.dimensions.width, height: size.dimensions.height)
            .background { StyleBackground(profile: profile) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Widget preview: \(text)")
    }
}
