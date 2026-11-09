import SwiftUI

struct ProfilesView: View {
    @Environment(LibraryStore.self) private var store
    @State private var path: [UUID] = []

    private var kind: StyleKind { store.library.layoutMode == .multi ? .multi : .single }
    private var builtIn: StyleProfile { kind == .multi ? .builtInMultiDefault : .builtInDefault }
    private var custom: [StyleProfile] { store.library.profiles(of: kind) }

    private var layoutBinding: Binding<LayoutMode> {
        Binding(get: { store.library.layoutMode }, set: { store.setLayoutMode($0) })
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Picker("Layout", selection: layoutBinding) {
                        Text("One widget").tag(LayoutMode.single)
                        Text("Multiple widgets").tag(LayoutMode.multi)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } footer: {
                    Text(kind == .multi
                        ? "One text is fitted across two Lock Screen widgets. Add Multi Widget: Left and Multi Widget: Right side by side."
                        : "Each widget shows the text on its own.")
                }

                Section {
                    row(for: builtIn, isEditable: false)
                    ForEach(custom) { profile in
                        row(for: profile, isEditable: true)
                    }
                    .onDelete { offsets in
                        offsets.map { custom[$0].id }.forEach(store.deleteProfile)
                    }
                } header: {
                    Text(kind == .multi ? "Multiple widget styles" : "Styles")
                } footer: {
                    Text(kind == .multi
                        ? "Multiple widgets use the checked style. With none checked, your first multiple widget style is used."
                        : "Widgets use the checked style. With none checked, the default is used.")
                }
            }
            .animation(.default, value: kind)
            .navigationTitle("Styles")
            .navigationDestination(for: UUID.self) { id in
                ProfileEditorHost(id: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !custom.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("New Style", systemImage: "plus") {
                        Button("Blank Style", systemImage: "doc") {
                            let profile = blankProfile()
                            store.addProfile(profile)
                            path.append(profile.id)
                        }
                        Menu("From Existing Style", systemImage: "plus.square.on.square") {
                            Button(builtIn.name) { duplicate(builtIn) }
                            ForEach(custom) { profile in
                                Button(profile.name) { duplicate(profile) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func blankProfile() -> StyleProfile {
        let number = custom.count + 1
        if kind == .multi { return .newMulti(name: "Multi Style \(number)") }
        var profile = StyleProfile()
        profile.name = "Style \(number)"
        return profile
    }

    private func duplicate(_ profile: StyleProfile) {
        path.append(store.duplicateProfile(profile).id)
    }

    private func isSelected(_ profile: StyleProfile) -> Bool {
        store.library.activeProfile(for: profile.kind).id == profile.id
    }

    private func row(for profile: StyleProfile, isEditable: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                store.selectProfile(profile)
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
        let size = profile.kind == .multi ? "up to \(Int(profile.fontSize)) pt" : "\(Int(profile.fontSize)) pt"
        return "\(font) · \(profile.weight.label) · \(size)"
    }
}
