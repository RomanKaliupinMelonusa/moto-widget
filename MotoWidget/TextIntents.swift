import AppIntents
import WidgetKit

struct TextEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Text"
    static let defaultQuery = TextEntityQuery()

    var id: UUID
    var content: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(content)")
    }

    init(_ text: SavedText) {
        id = text.id
        content = text.content
    }
}

struct TextEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TextEntity] {
        LibraryStorage.load().texts.filter { identifiers.contains($0.id) }.map(TextEntity.init)
    }

    func suggestedEntities() async throws -> [TextEntity] {
        LibraryStorage.load().texts.map(TextEntity.init)
    }
}

struct SelectTextIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Text"
    static let description = IntentDescription("Pick a saved text, or leave it empty to follow the current text.")

    @Parameter(title: "Text")
    var text: TextEntity?
}

struct NextTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Text"
    static let description = IntentDescription("Switch the current text to the next saved text.")

    func perform() async throws -> some IntentResult {
        var library = LibraryStorage.load()
        library.advanceCurrentText()
        LibraryStorage.save(library)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
