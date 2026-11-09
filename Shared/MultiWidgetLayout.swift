import SwiftUI
import UIKit

/// Splits one text across the widgets of a multi-widget set and picks a single font size that fits every part.
nonisolated enum MultiWidgetLayout {
    static let partCount = 2

    struct Result: Sendable {
        let segments: [String]
        let fontSize: Double
        /// 0 means unlimited.
        var lineLimit = 0
    }

    static func layout(text: String, profile: StyleProfile, partSize: CGSize) -> Result {
        let words = tokens(profile.textCase.apply(to: text))
        guard !words.isEmpty else { return Result(segments: ["", ""], fontSize: profile.fontSize) }

        let largest = Int(min(max(profile.fontSize, 8), 120))

        // One unbroken word has no break points, so cut it in half by characters.
        if words.count == 1 {
            let characters = Array(words[0].text)
            let middle = (characters.count + 1) / 2
            let halves = [String(characters[..<middle]), String(characters[middle...])]
            let halfTokens = halves.map { Token(text: $0, spaceAfter: false) }
            for size in stride(from: largest, through: 8, by: -1) {
                let metrics = Metrics(profile: profile, size: Double(size), partSize: partSize, words: halfTokens)
                if halfTokens.indices.allSatisfy(metrics.fitsWrapped) {
                    return Result(segments: halves, fontSize: Double(size))
                }
            }
            return Result(segments: halves, fontSize: 8)
        }

        // The text flows across both widgets as rows; each row is cut once, so the parts line up.
        for size in stride(from: largest, through: 8, by: -1) {
            let metrics = Metrics(profile: profile, size: Double(size), partSize: partSize, words: words)
            guard let rows = metrics.rows() else { continue }
            let left = rows.map { join(words, $0.left) }
            let right = rows.map { $0.right.isEmpty ? "\u{200B}" : join(words, $0.right) }
            return Result(segments: [left.joined(separator: "\n"), right.joined(separator: "\n")], fontSize: Double(size), lineLimit: rows.count)
        }
        let half = max(1, words.count / 2)
        return Result(segments: [join(words, 0..<half), join(words, half..<words.count)], fontSize: 8)
    }

    /// A piece of text that can end a line. A break character stays attached to the piece before it.
    fileprivate struct Token {
        let text: String
        var spaceAfter: Bool
    }

    private static let breakCharacters: Set<Character> = ["-", "\u{2010}", "\u{2013}", "\u{2014}", "/", "\\", "_", "|"]

    private static func tokens(_ text: String) -> [Token] {
        var result: [Token] = []
        var current = ""
        for character in text {
            if character.isWhitespace {
                if !current.isEmpty {
                    result.append(Token(text: current, spaceAfter: true))
                    current = ""
                } else if !result.isEmpty {
                    result[result.count - 1].spaceAfter = true
                }
            } else {
                current.append(character)
                // Only break after a break character that follows a letter or digit, so "--" or "/" alone stay put.
                if breakCharacters.contains(character), current.count > 1, !breakCharacters.contains(current[current.index(before: current.index(before: current.endIndex))]) {
                    result.append(Token(text: current, spaceAfter: false))
                    current = ""
                }
            }
        }
        if !current.isEmpty { result.append(Token(text: current, spaceAfter: false)) }
        return result
    }

    private static func join(_ words: [Token], _ range: Range<Int>) -> String {
        range.map { index in
            words[index].text + (words[index].spaceAfter && index < range.upperBound - 1 ? " " : "")
        }.joined()
    }

    private struct Metrics {
        let widths: [CGFloat]
        let spaceAfter: [Bool]
        let spaceWidth: CGFloat
        let maxWidth: CGFloat
        let maxLines: Int

        init(profile: StyleProfile, size: Double, partSize: CGSize, words: [Token]) {
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
            widths = words.map { measure($0.text) }
            spaceAfter = words.map(\.spaceAfter)
            spaceWidth = measure(" ")
            maxWidth = partSize.width * 0.96

            let spacing = profile.lineSpacing
            var lines = max(1, Int((partSize.height * 0.98 + spacing) / max(font.lineHeight + spacing, 1)))
            if profile.lineLimit > 0 { lines = min(lines, profile.lineLimit) }
            maxLines = lines
        }

        func lineWidth(_ range: Range<Int>) -> CGFloat {
            range.reduce(0) { total, index in
                total + widths[index] + (spaceAfter[index] && index < range.upperBound - 1 ? spaceWidth : 0)
            }
        }

        /// A word longer than a line wraps by character.
        func fitsWrapped(_ index: Int) -> Bool {
            Int((widths[index] / maxWidth).rounded(.up)) <= maxLines
        }

        /// Splits the words into at most `maxLines` rows, each cut once into a left and a right piece that
        /// each fit one line. Picks the rows whose two pieces are closest in width. Nil if none fit.
        func rows() -> [(left: Range<Int>, right: Range<Int>)]? {
            let count = widths.count
            var cost = Array(repeating: Array(repeating: Double.infinity, count: count + 1), count: maxLines + 1)
            var choice = Array(repeating: Array(repeating: (split: 0, end: 0), count: count + 1), count: maxLines + 1)
            for used in 0...maxLines { cost[used][count] = 0 }

            for used in 1...maxLines {
                for start in stride(from: count - 1, through: 0, by: -1) {
                    var split = start + 1
                    while split <= count, lineWidth(start..<split) <= maxWidth {
                        let left = lineWidth(start..<split)
                        var end = split
                        while end <= count, end == split || lineWidth(split..<end) <= maxWidth {
                            let rest = cost[used - 1][end]
                            if rest < .infinity {
                                let right = end == split ? 0 : lineWidth(split..<end)
                                let imbalance = Double((left - right) / maxWidth)
                                let total = (end == split ? 0.4 : imbalance * imbalance) + rest
                                if total < cost[used][start] {
                                    cost[used][start] = total
                                    choice[used][start] = (split, end)
                                }
                            }
                            end += 1
                        }
                        split += 1
                    }
                }
            }

            guard cost[maxLines][0] < .infinity else { return nil }
            var result: [(left: Range<Int>, right: Range<Int>)] = []
            var start = 0, used = maxLines
            while start < count {
                let (split, end) = choice[used][start]
                result.append((start..<split, split..<end))
                start = end
                used -= 1
            }
            return result
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

    /// Space kept on the outer edge so text doesn't touch the rounded corner; the inner edge stays flush.
    private static let outerInset: CGFloat = 6

    /// Centered text hugs the gap between the widgets so the halves read as one line.
    private var partProfile: StyleProfile {
        var aligned = profile
        if profile.horizontalAlignment == .center {
            aligned.horizontalAlignment = part == 0 ? .trailing : .leading
        }
        return aligned
    }

    var body: some View {
        GeometryReader { geo in
            let inner = CGSize(width: geo.size.width - Self.outerInset, height: geo.size.height)
            let result = MultiWidgetLayout.layout(text: text, profile: profile, partSize: inner)
            StyledTextView(text: result.segments[part], profile: partProfile, slot: .part(fontSize: result.fontSize, lineLimit: result.lineLimit))
                .frame(width: inner.width, height: inner.height)
                .frame(width: geo.size.width, height: geo.size.height, alignment: part == 0 ? .trailing : .leading)
        }
        .ignoresSafeArea()
    }
}
