import SwiftUI

// MARK: - Option enums

nonisolated protocol OptionEnum: RawRepresentable<String>, CaseIterable, Identifiable, Hashable, Sendable {}

extension OptionEnum {
    nonisolated var id: String { rawValue }

    /// "ultraLight" -> "Ultra Light"
    nonisolated var label: String {
        rawValue.reduce(into: "") { $0 += $1.isUppercase ? " \($1)" : "\($1)" }.capitalized
    }
}

nonisolated enum DesignOption: String, Codable, OptionEnum {
    case `default`, rounded, serif, monospaced

    var value: Font.Design {
        switch self {
        case .default: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

nonisolated enum WeightOption: String, Codable, OptionEnum {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    var value: Font.Weight {
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

nonisolated enum WidthOption: String, Codable, OptionEnum {
    case compressed, condensed, standard, expanded

    var value: Font.Width {
        switch self {
        case .compressed: .compressed
        case .condensed: .condensed
        case .standard: .standard
        case .expanded: .expanded
        }
    }
}

nonisolated enum HorizontalOption: String, Codable, OptionEnum {
    case leading, center, trailing

    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

nonisolated enum VerticalOption: String, Codable, OptionEnum {
    case top, center, bottom

    var vertical: VerticalAlignment {
        switch self {
        case .top: .top
        case .center: .center
        case .bottom: .bottom
        }
    }
}

nonisolated enum CaseOption: String, Codable, OptionEnum {
    case none, uppercase, lowercase, capitalized

    func apply(to text: String) -> String {
        switch self {
        case .none: text
        case .uppercase: text.uppercased()
        case .lowercase: text.lowercased()
        case .capitalized: text.capitalized
        }
    }
}

nonisolated enum FillKind: String, Codable, OptionEnum {
    case automatic, solid, linear, radial, mesh
}

/// A single-widget style, or one that fits a text across several widgets.
nonisolated enum StyleKind: String, Codable, Sendable {
    case single, multi
}

// MARK: - Color & fill

nonisolated struct RGBAColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity) }

    static let black = RGBAColor(red: 0, green: 0, blue: 0)
    static let white = RGBAColor(red: 1, green: 1, blue: 1)
}

nonisolated struct FillSpec: Codable, Hashable, Sendable {
    var kind: FillKind = .automatic
    /// Always four entries: solid uses [0], linear/radial use [0...1], mesh uses all four.
    var colors: [RGBAColor] = [
        RGBAColor(red: 0.20, green: 0.45, blue: 1.0),
        RGBAColor(red: 0.65, green: 0.25, blue: 0.95),
        RGBAColor(red: 1.0, green: 0.45, blue: 0.45),
        RGBAColor(red: 1.0, green: 0.8, blue: 0.3),
    ]
    /// Degrees, used by linear gradients.
    var angle: Double = 45

    func shapeStyle(automatic: AnyShapeStyle) -> AnyShapeStyle {
        let c = (colors + Array(repeating: RGBAColor.black, count: 4)).prefix(4).map(\.color)
        switch kind {
        case .automatic:
            return automatic
        case .solid:
            return AnyShapeStyle(c[0])
        case .linear:
            let radians = angle * .pi / 180
            let dx = cos(radians) / 2, dy = sin(radians) / 2
            return AnyShapeStyle(LinearGradient(
                colors: [c[0], c[1]],
                startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
                endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
            ))
        case .radial:
            return AnyShapeStyle(RadialGradient(colors: [c[0], c[1]], center: .center, startRadius: 0, endRadius: 200))
        case .mesh:
            return AnyShapeStyle(MeshGradient(
                width: 2, height: 2,
                points: [[0, 0], [1, 0], [0, 1], [1, 1]],
                colors: c
            ))
        }
    }
}

// MARK: - Profile

nonisolated enum LockScreenSlot: Sendable, Equatable {
    case rectangular, circular
    /// One widget of a multi-widget set; the text is already split and sized.
    case part(fontSize: Double, lineLimit: Int)
}

nonisolated struct StyleProfile: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name = "New Style"

    // Font
    var usesCustomFont = false
    var customFontFamily = ""
    var design: DesignOption = .default
    var weight: WeightOption = .semibold
    var width: WidthOption = .standard
    var isItalic = false
    var usesSmallCaps = false
    var usesMonospacedDigits = false
    var fontSize: Double = 28
    var autoShrink = true
    var minimumScale: Double = 0.5

    // Text
    var textCase: CaseOption = .none
    var underline = false
    var strikethrough = false
    var tracking: Double = 0
    var lineSpacing: Double = 0
    /// 0 means unlimited.
    var lineLimit = 0
    var textFill = FillSpec()
    var textOpacity: Double = 1

    // Shadow
    var hasShadow = false
    var shadowColor = RGBAColor(red: 0, green: 0, blue: 0, opacity: 0.4)
    var shadowRadius: Double = 4
    var shadowX: Double = 0
    var shadowY: Double = 2

    // Layout
    var horizontalAlignment: HorizontalOption = .center
    var verticalAlignment: VerticalOption = .center
    var contentPadding: Double = 0
    var rotation: Double = 0

    // Background
    var background = FillSpec()

    // Widget
    var tintsInAccentedMode = true

    // Lock Screen. Stored optional so styles saved before these existed still decode.
    var lockRectangularSizeStored: Double?
    var lockCircularSizeStored: Double?
    var lockShrinksStored: Bool?
    var lockMinimumScaleStored: Double?
    var lockLineLimitStored: Int?
    var kindStored: StyleKind?

    var kind: StyleKind {
        get { kindStored ?? .single }
        set { kindStored = newValue }
    }
    var lockRectangularSize: Double {
        get { lockRectangularSizeStored ?? 40 }
        set { lockRectangularSizeStored = newValue }
    }
    var lockCircularSize: Double {
        get { lockCircularSizeStored ?? 18 }
        set { lockCircularSizeStored = newValue }
    }
    var lockShrinks: Bool {
        get { lockShrinksStored ?? true }
        set { lockShrinksStored = newValue }
    }
    var lockMinimumScale: Double {
        get { lockMinimumScaleStored ?? 0.3 }
        set { lockMinimumScaleStored = newValue }
    }
    /// 0 means unlimited.
    var lockLineLimit: Int {
        get { lockLineLimitStored ?? 0 }
        set { lockLineLimitStored = newValue }
    }

    static let builtInDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static let builtInDefault = StyleProfile(id: builtInDefaultID, name: "Default")

    static let builtInMultiID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    /// For multi styles, `fontSize` is the largest size tried when fitting the text.
    static func newMulti(id: UUID = UUID(), name: String = "Multi Widget") -> StyleProfile {
        StyleProfile(id: id, name: name, fontSize: 44, kindStored: .multi)
    }

    static let builtInMultiDefault = newMulti(id: builtInMultiID, name: "Multi Widget Default")

    func font(size: Double) -> Font {
        var font: Font
        if usesCustomFont, !customFontFamily.isEmpty {
            font = Font.custom(customFontFamily, fixedSize: size).weight(weight.value)
        } else {
            font = Font.system(size: size, weight: weight.value, design: design.value).width(width.value)
        }
        if isItalic { font = font.italic() }
        if usesSmallCaps { font = font.smallCaps() }
        if usesMonospacedDigits { font = font.monospacedDigit() }
        return font
    }

    var shadowOpacityColor: Color { hasShadow ? shadowColor.color : .clear }
}

// MARK: - Library

nonisolated struct SavedText: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var content: String
}

nonisolated enum LayoutMode: String, Codable, Sendable {
    case single, multi
}

nonisolated struct Library: Codable, Sendable {
    var texts: [SavedText] = []
    var profiles: [StyleProfile] = []
    /// nil selects the built-in default profile.
    var selectedProfileID: UUID?
    var currentTextID: UUID?
    /// Optional so libraries saved before multi-widget styles still decode.
    var layoutModeStored: LayoutMode?
    var selectedMultiProfileID: UUID?

    var layoutMode: LayoutMode {
        get { layoutModeStored ?? .single }
        set { layoutModeStored = newValue }
    }

    var activeProfile: StyleProfile {
        profiles.first { $0.id == selectedProfileID && $0.kind == .single } ?? .builtInDefault
    }

    /// An explicit choice wins; otherwise the first custom multi style, then the built-in one.
    var activeMultiProfile: StyleProfile {
        if selectedMultiProfileID == StyleProfile.builtInMultiID { return .builtInMultiDefault }
        return profiles.first { $0.id == selectedMultiProfileID && $0.kind == .multi }
            ?? profiles.first { $0.kind == .multi }
            ?? .builtInMultiDefault
    }

    func activeProfile(for kind: StyleKind) -> StyleProfile {
        kind == .multi ? activeMultiProfile : activeProfile
    }

    /// The style the app previews, following the chosen layout mode.
    var displayProfile: StyleProfile { activeProfile(for: layoutMode == .multi ? .multi : .single) }

    func profiles(of kind: StyleKind) -> [StyleProfile] {
        profiles.filter { $0.kind == kind }
    }

    var currentText: SavedText? {
        texts.first { $0.id == currentTextID } ?? texts.first
    }

    /// A pinned text wins; otherwise the current text is used.
    func text(pinnedID: UUID?) -> SavedText? {
        if let pinnedID, let match = texts.first(where: { $0.id == pinnedID }) { return match }
        return currentText
    }

    mutating func advanceCurrentText() {
        guard !texts.isEmpty else { return }
        let index = texts.firstIndex { $0.id == currentText?.id } ?? 0
        currentTextID = texts[(index + 1) % texts.count].id
    }
}

nonisolated enum LibraryStorage {
    // Must match the App Group in Config/*.entitlements.
    static let appGroupID = "group.com.romankaliupin.motowidget"
    private static let key = "library.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func load() -> Library {
        guard let data = defaults.data(forKey: key),
              let library = try? JSONDecoder().decode(Library.self, from: data)
        else { return Library() }
        return library
    }

    static func save(_ library: Library) {
        guard let data = try? JSONEncoder().encode(library) else { return }
        defaults.set(data, forKey: key)
    }
}
