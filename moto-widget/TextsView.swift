import SwiftUI

struct TextsView: View {
    @Environment(LibraryStore.self) private var store
    @State private var editing: SavedText?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        WidgetPreview(
                            text: store.library.currentText?.content ?? "Add some text",
                            profile: store.library.displayProfile,
                            size: store.library.layoutMode == .multi ? .lockPair : .small
                        )
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Widget preview")
                } footer: {
                    if store.library.layoutMode == .multi {
                        Text("The text is split across the Multi Widget Left and Right widgets.")
                    }
                }

                Section {
                    ForEach(store.library.texts) { item in
                        row(for: item)
                    }
                    .onDelete { store.deleteTexts(at: $0) }
                } header: {
                    Text("Saved texts")
                } footer: {
                    Text("The checked text is shown by widgets that have no text chosen. Tap a widget to cycle through your texts.")
                }
            }
            .overlay {
                if store.library.texts.isEmpty {
                    ContentUnavailableView(
                        "No Texts",
                        systemImage: "text.quote",
                        description: Text("Tap + to add text for your widget.")
                    )
                    .offset(y: 120)
                }
            }
            .navigationTitle("Texts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.library.texts.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Text", systemImage: "plus") { editing = SavedText(content: "") }
                }
            }
            .sheet(item: $editing) { item in
                TextEditSheet(text: item) { store.upsert($0) }
            }
        }
    }

    private func row(for item: SavedText) -> some View {
        Button {
            store.setCurrentText(item.id)
        } label: {
            HStack {
                Text(item.content)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                Spacer()
                if store.library.currentText?.id == item.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Current text")
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { store.deleteText(item.id) }
        }
        .swipeActions(edge: .leading) {
            Button("Edit", systemImage: "pencil") { editing = item }
                .tint(.blue)
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editing = item }
            Button("Delete", systemImage: "trash", role: .destructive) { store.deleteText(item.id) }
        }
    }
}

private struct TextEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var text: SavedText
    let onSave: (SavedText) -> Void

    var body: some View {
        NavigationStack {
            TextEditor(text: $text.content)
                .padding()
                .navigationTitle("Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(text)
                            dismiss()
                        }
                        .disabled(text.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
