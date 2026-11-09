import SwiftUI
import WidgetKit

@MainActor @Observable
final class LibraryStore {
    private(set) var library: Library
    private var reloadTask: Task<Void, Never>?

    init() {
        library = LibraryStorage.load()
    }

    /// Re-reads shared storage, e.g. after the widget advanced the current text.
    func refresh() {
        library = LibraryStorage.load()
    }

    // MARK: Texts

    func upsert(_ text: SavedText) {
        if let index = library.texts.firstIndex(where: { $0.id == text.id }) {
            library.texts[index] = text
        } else {
            library.texts.append(text)
        }
        commit()
    }

    func deleteTexts(at offsets: IndexSet) {
        library.texts.remove(atOffsets: offsets)
        commit()
    }

    func deleteText(_ id: UUID) {
        library.texts.removeAll { $0.id == id }
        commit()
    }

    func setCurrentText(_ id: UUID) {
        library.currentTextID = id
        commit()
    }

    // MARK: Profiles

    func addProfile(_ profile: StyleProfile) {
        library.profiles.append(profile)
        commit()
    }

    func update(_ profile: StyleProfile) {
        guard let index = library.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        library.profiles[index] = profile
        commit()
    }

    func deleteProfile(_ id: UUID) {
        library.profiles.removeAll { $0.id == id }
        if library.selectedProfileID == id { library.selectedProfileID = nil }
        if library.selectedMultiProfileID == id { library.selectedMultiProfileID = nil }
        commit()
    }

    func selectProfile(_ profile: StyleProfile) {
        switch profile.kind {
        case .single:
            library.selectedProfileID = profile.id == StyleProfile.builtInDefaultID ? nil : profile.id
        case .multi:
            library.selectedMultiProfileID = profile.id
        }
        commit()
    }

    func setLayoutMode(_ mode: LayoutMode) {
        library.layoutMode = mode
        commit()
    }

    func duplicateProfile(_ profile: StyleProfile) -> StyleProfile {
        var copy = profile
        copy.id = UUID()
        copy.name = "\(profile.name) Copy"
        addProfile(copy)
        return copy
    }

    // MARK: Persistence

    private func commit() {
        LibraryStorage.save(library)
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
