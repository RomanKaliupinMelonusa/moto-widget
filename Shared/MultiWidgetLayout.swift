import SwiftUI
import UIKit

/// Splits one text across the widgets of a multi-widget set and picks a single font size that fits every part.
nonisolated enum MultiWidgetLayout {
    static let partCount = 2

    struct Result: Sendable {
        let segments: [String]
        let fontSize: Double
    }

    static func layout(text: String, profile: StyleProfile, partSize: CGSize) -> Result {
        let words = profile.textCase.apply(to: text).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return Result(segments: ["", ""], fontSize: profile.fontSize) }

        // With a single word the second widget stays empty.
        let splits = words.count == 1 ? [1] : Array(1..<words.count)
        let largest = Int(min(max(profile.fontSize, 8), 120))

        for size in stride(from: largest, through: 8, by: -1) {
            let metrics = Metrics(profile: profile, size: Double(size), partSize: partSize, words: words)
            var best: (split: Int, imbalance: CGFloat)?
            for split in splits {
                let left = 0..<split, right = split..<words.count
                guard metrics.fits(left), metrics.fits(right) else { continue }
                let imbalance = abs(metrics.lineWidth(left) - metrics.lineWidth(right))
                if best == nil || imbalance < best!.imbalance { best = (split, imbalance) }
            }
            if let best {
                return Result(segments: segments(words, split: best.split), fontSize: Double(size))
            }
        }
        return Result(segments: segments(words, split: max(1, words.count / 2)), fontSize: 8)
    }

    private static func segments(_ words: [String], split: Int) -> [String] {
        [words[..<split].joined(separator: " "), words[split...].joined(separator: " ")]
    }

    private struct Metrics {
        let widths: [CGFloat]
        let spaceWidth: CGFloat
        let maxWidth: CGFloat
        let maxLines: Int

        init(profile: StyleProfile, size: Double, partSize: CGSize, words: [String]) {
            let font = Self.font(for: profile, size: size)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .kern: profile.tracking]
            // UIKit has no width axis for the system font, so approximate it.
            let widthFactor: CGFloat = switch profile.width {
            case .compressed: 0.82
            case .condensed: 0.9
            case .standard: 1
            case .expanded: 1.1
            }
            let factor: CGFloat = profile.usesCustomFont ? 1 : widthFactor
            func measure(_ string: String) -> CGFloat {
                (string as NSString).size(withAttributes: attributes).width * factor
            }
            widths = words.map(measure)
            spaceWidth = measure(" ")
            maxWidth = partSize.width * 0.96

            let spacing = profile.lineSpacing
            var lines = max(1, Int((partSize.height * 0.98 + spacing) / max(font.lineHeight + spacing, 1)))
            if profile.lineLimit > 0 { lines = min(lines, profile.lineLimit) }
            maxLines = lines
        }

        func lineWidth(_ range: Range<Int>) -> CGFloat {
            range.reduce(0) { $0 + widths[$1] } + spaceWidth * CGFloat(max(range.count - 1, 0))
        }

        /// Greedy word wrap, as Text does.
        func fits(_ range: Range<Int>) -> Bool {
            var lines = 1
            var current: CGFloat = 0
            for index in range {
                let width = widths[index]
                if width > maxWidth { return false }
                let needed = current == 0 ? width : current + spaceWidth + width
                if needed <= maxWidth {
                    current = needed
                } else {
                    lines += 1
                    current = width
                }
            }
            return lines <= maxLines
        }

        private static func font(for profile: StyleProfile, size: Double) -> UIFont {
            let weight = profile.weight.uiWeight
            if profile.usesCustomFont, !profile.customFontFamily.isEmpty {
                var descriptor = UIFontDescriptor(fontAttributes: [
                    .family: profile.customFontFamily,
                    .traits: [UIFontDescriptor.TraitKey.weight: weight],
                ])
                if profile.isItalic { descriptor = descriptor.withSymbolicTraits(.traitItalic) ?? descriptor }
                return UIFont(descriptor: descriptor, size: size)
            }
            var font = UIFont.systemFont(ofSize: size, weight: weight)
            var descriptor = font.fontDescriptor
            if let designed = descriptor.withDesign(profile.design.uiDesign) { descriptor = designed }
            if profile.isItalic { descriptor = descriptor.withSymbolicTraits(.traitItalic) ?? descriptor }
            font = UIFont(descriptor: descriptor, size: size)
            return font
        }
    }
}

extension WeightOption {
    nonisolated var uiWeight: UIFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

extension DesignOption {
    nonisolated var uiDesign: UIFontDescriptor.SystemDesign {
        switch self {
        case .default: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

/// One widget of a multi-widget set. Every part runs the same layout, so they agree on the split and the size.
struct MultiPartText: View {
    let text: String
    let profile: StyleProfile
    let part: Int

    var body: some View {
        GeometryReader { geo in
            let result = MultiWidgetLayout.layout(text: text, profile: profile, partSize: geo.size)
            StyledTextView(text: result.segments[part], profile: profile, slot: .part(fontSize: result.fontSize))
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
