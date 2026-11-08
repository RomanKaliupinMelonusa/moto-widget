import SwiftUI

struct ProfilesView: View {
    @Environment(LibraryStore.self) private var store
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    row(for: .builtInDefault, isEditable: false)
                    ForEach(store.library.profiles) { profile in
                        row(for: profile, isEditable: true)
                    }
                    .onDelete { store.deleteProfiles(at: $0) }
                } footer: {
                    Text("Only one style is used by widgets. When no custom style is selected, the default is used.")
                }
            }
            .navigationTitle("Styles")
            .navigationDestination(for: UUID.self) { id in
                ProfileEditorHost(id: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.library.profiles.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("New Style", systemImage: "plus") {
                        Button("Blank Style", systemImage: "doc") {
                            var profile = StyleProfile()
                            profile.name = "Style \(store.library.profiles.count + 1)"
                            store.addProfile(profile)
                            path.append(profile.id)
                        }
                        Menu("From Existing Style", systemImage: "plus.square.on.square") {
                            Button(StyleProfile.builtInDefault.name) { duplicate(.builtInDefault) }
                            ForEach(store.library.profiles) { profile in
                                Button(profile.name) { duplicate(profile) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func duplicate(_ profile: StyleProfile) {
        path.append(store.duplicateProfile(profile).id)
    }

    private func isSelected(_ profile: StyleProfile) -> Bool {
        store.library.activeProfile.id == profile.id
    }

    private func row(for profile: StyleProfile, isEditable: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                store.selectProfile(profile.id)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isSelected(profile) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected(profile) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    VStack(alignment: .leading) {
                        Text(profile.name).foregroundStyle(.primary)
                        Text(summary(of: profile)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityAddTraits(isSelected(profile) ? .isSelected : [])

            if isEditable {
                Button("Edit", systemImage: "slider.horizontal.3") { path.append(profile.id) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
        }
        .swipeActions(edge: .trailing) {
            if isEditable {
                Button("Delete", systemImage: "trash", role: .destructive) { store.deleteProfile(profile.id) }
            }
        }
        .swipeActions(edge: .leading) {
            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(profile) }
                .tint(.indigo)
        }
        .contextMenu {
            if isEditable {
                Button("Edit", systemImage: "slider.horizontal.3") { path.append(profile.id) }
            }
            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(profile) }
            if isEditable {
                Button("Delete", systemImage: "trash", role: .destructive) { store.deleteProfile(profile.id) }
            }
        }
    }

    private func summary(of profile: StyleProfile) -> String {
        let font = profile.usesCustomFont && !profile.customFontFamily.isEmpty ? profile.customFontFamily : profile.design.label
        return "\(font) · \(profile.weight.label) · \(Int(profile.fontSize)) pt"
    }
}
