import SwiftUI

/// Renders text using a style profile. Shared by the app preview and the widget.
struct StyledTextView: View {
    let text: String
    let profile: StyleProfile
    var slot: LockScreenSlot?

    var body: some View {
        let isPart: Bool = if case .part = slot { true } else { false }
        let size = switch slot {
        case .rectangular: profile.lockRectangularSize
        case .circular: profile.lockCircularSize
        case .part(let fontSize): fontSize
        case nil: profile.fontSize
        }
        // Parts are sized by the splitter; the floor only guards against measurement error.
        let minimumScale: Double = if isPart {
            0.5
        } else if slot == nil {
            profile.autoShrink ? profile.minimumScale : 1
        } else {
            profile.lockShrinks ? profile.lockMinimumScale : 1
        }
        let lineLimit = isPart ? 0 : (slot == nil ? profile.lineLimit : profile.lockLineLimit)
        Text(profile.textCase.apply(to: text))
            .font(profile.font(size: size))
            .tracking(profile.tracking)
            .underline(profile.underline)
            .strikethrough(profile.strikethrough)
            .lineSpacing(profile.lineSpacing)
            .lineLimit(lineLimit == 0 ? nil : lineLimit)
            .minimumScaleFactor(minimumScale)
            .multilineTextAlignment(profile.horizontalAlignment.textAlignment)
            .foregroundStyle(profile.textFill.shapeStyle(automatic: AnyShapeStyle(.primary)))
            .opacity(profile.textOpacity)
            .shadow(
                color: profile.shadowOpacityColor,
                radius: profile.hasShadow ? profile.shadowRadius : 0,
                x: profile.shadowX,
                y: profile.shadowY
            )
            .rotationEffect(.degrees(isPart ? 0 : profile.rotation))
            .padding(isPart ? 0 : profile.contentPadding)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: Alignment(horizontal: profile.horizontalAlignment.horizontal, vertical: profile.verticalAlignment.vertical)
            )
    }
}

struct StyleBackground: View {
    let profile: StyleProfile

    var body: some View {
        Rectangle()
            .fill(profile.background.shapeStyle(automatic: AnyShapeStyle(Color(uiColor: .systemBackground))))
    }
}
