import AppIntents
import SwiftUI
import WidgetKit

struct TextEntry: TimelineEntry {
    let date: Date
    let text: String?
    let profile: StyleProfile
    /// True when tapping the widget should switch to the next saved text.
    let canAdvance: Bool
    /// Index of this widget within a multi-widget set; nil for a standalone widget.
    var part: Int?
}

struct TextProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TextEntry {
        TextEntry(date: .now, text: "Your text", profile: .builtInDefault, canAdvance: false)
    }

    func snapshot(for configuration: SelectTextIntent, in context: Context) async -> TextEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectTextIntent, in context: Context) async -> Timeline<TextEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SelectTextIntent) -> TextEntry {
        let library = LibraryStorage.load()
        let pinnedID = configuration.text?.id
        return TextEntry(
            date: .now,
            text: library.text(pinnedID: pinnedID)?.content,
            profile: library.activeProfile,
            canAdvance: pinnedID == nil && library.texts.count > 1
        )
    }
}

/// Shows the current text, using the multi-widget style, for one widget of a set.
struct PartProvider: TimelineProvider {
    let part: Int

    func placeholder(in context: Context) -> TextEntry {
        TextEntry(date: .now, text: "Your text", profile: .builtInMultiDefault, canAdvance: false, part: part)
    }

    func getSnapshot(in context: Context, completion: @escaping (TextEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TextEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .never))
    }

    private func entry() -> TextEntry {
        let library = LibraryStorage.load()
        return TextEntry(
            date: .now,
            text: library.currentText?.content,
            profile: library.activeMultiProfile,
            canAdvance: library.texts.count > 1,
            part: part
        )
    }
}

struct TextWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TextEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isAccessory {
                    Color.clear
                } else {
                    StyleBackground(profile: entry.profile)
                }
            }
    }

    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: true
        default: false
        }
    }

    @ViewBuilder
    private var content: some View {
        if let text = entry.text, !text.isEmpty {
            switch family {
            case .accessoryInline:
                Text(entry.profile.textCase.apply(to: text))
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    styled(text, slot: .circular)
                }
            case .accessoryRectangular:
                tappable { rectangular(text) }
            default:
                tappable { styled(text, slot: nil) }
            }
        } else {
            Text("Open Moto Widget to add some text")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func rectangular(_ text: String) -> some View {
        if let part = entry.part {
            MultiPartText(text: text, profile: entry.profile, part: part)
                .widgetAccentable(entry.profile.tintsInAccentedMode)
        } else {
            styled(text, slot: .rectangular)
        }
    }

    private func styled(_ text: String, slot: LockScreenSlot?) -> some View {
        StyledTextView(text: text, profile: entry.profile, slot: slot)
            .widgetAccentable(entry.profile.tintsInAccentedMode)
    }

    @ViewBuilder
    private func tappable<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if entry.canAdvance {
            Button(intent: NextTextIntent()) { content() }
                .buttonStyle(.plain)
        } else {
            content()
        }
    }
}

struct MotoTextLeftWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MotoTextLeftWidget", provider: PartProvider(part: 0)) { entry in
            TextWidgetView(entry: entry)
        }
        .configurationDisplayName("Split Text 1 of 2")
        .description("Add next to Split Text 2 of 2. Your text is split between them automatically.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct MotoTextRightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MotoTextRightWidget", provider: PartProvider(part: 1)) { entry in
            TextWidgetView(entry: entry)
        }
        .configurationDisplayName("Split Text 2 of 2")
        .description("Add next to Split Text 1 of 2. Your text is split between them automatically.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct MotoTextWidget: Widget {
    let kind = "MotoTextWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectTextIntent.self, provider: TextProvider()) { entry in
            TextWidgetView(entry: entry)
        }
        .configurationDisplayName("Moto Text")
        .description("Shows your saved text with the selected style.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryRectangular, .accessoryCircular, .accessoryInline,
        ])
    }
}

#Preview(as: .systemSmall) {
    MotoTextWidget()
} timeline: {
    TextEntry(date: .now, text: "Hello, world!", profile: .builtInDefault, canAdvance: true)
}
