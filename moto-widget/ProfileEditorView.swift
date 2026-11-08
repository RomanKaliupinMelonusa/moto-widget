import SwiftUI

/// Looks the profile up once so edits don't rebuild the editor and reset its state.
struct ProfileEditorHost: View {
    @Environment(LibraryStore.self) private var store
    let id: UUID
    @State private var profile: StyleProfile?

    var body: some View {
        Group {
            if let profile {
                ProfileEditorView(profile: profile)
            }
        }
        .onAppear {
            if profile == nil { profile = store.library.profiles.first { $0.id == id } }
        }
    }
}

struct ProfileEditorView: View {
    @Environment(LibraryStore.self) private var store
    @State private var draft: StyleProfile
    @SceneStorage("profileEditor.previewSize") private var previewSize: WidgetPreview.Size = .small

    init(profile: StyleProfile) {
        _draft = State(initialValue: profile)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Style name", text: $draft.name)
            }

            fontSection
            textSection
            layoutSection
            shadowSection
            backgroundSection
            lockScreenSection

            Section {
                Toggle("Tint text in accented mode", isOn: $draft.tintsInAccentedMode)
            } header: {
                Text("Widget")
            } footer: {
                Text("When the Home Screen uses tinted icons, text marked as accentable takes the tint color.")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { previewBar }
        .navigationTitle(draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: draft) { _, newValue in store.update(newValue) }
    }

    // MARK: Preview

    private var previewBar: some View {
        VStack(spacing: 8) {
            Picker("Preview size", selection: $previewSize) {
                ForEach(WidgetPreview.Size.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            ScrollView(.vertical) {
                WidgetPreview(
                    text: store.library.currentText?.content ?? "Sample text",
                    profile: draft,
                    size: previewSize
                )
                .padding(.vertical, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 200)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    // MARK: Sections

    private var fontSection: some View {
        Section("Font") {
            Toggle("Use installed font family", isOn: $draft.usesCustomFont)
            if draft.usesCustomFont {
                NavigationLink {
                    FontFamilyPicker(selection: $draft.customFontFamily)
                } label: {
                    LabeledContent("Family", value: draft.customFontFamily.isEmpty ? "Choose…" : draft.customFontFamily)
                }
            } else {
                OptionPicker("Design", selection: $draft.design)
                OptionPicker("Width", selection: $draft.width)
                Toggle("Small caps", isOn: $draft.usesSmallCaps)
                Toggle("Monospaced digits", isOn: $draft.usesMonospacedDigits)
            }
            OptionPicker("Weight", selection: $draft.weight)
            SliderRow("Size", value: $draft.fontSize, range: 8...240, step: 1, unit: "pt")
            Toggle("Italic", isOn: $draft.isItalic)
        }
    }

    private var textSection: some View {
        Section("Text") {
            OptionPicker("Letter case", selection: $draft.textCase)
            Toggle("Underline", isOn: $draft.underline)
            Toggle("Strikethrough", isOn: $draft.strikethrough)
            SliderRow("Letter spacing", value: $draft.tracking, range: -5...20, step: 0.5, unit: "pt")
            SliderRow("Line spacing", value: $draft.lineSpacing, range: -10...50, step: 1, unit: "pt")
            Stepper(value: $draft.lineLimit, in: 0...20) {
                LabeledContent("Line limit", value: draft.lineLimit == 0 ? "Unlimited" : "\(draft.lineLimit)")
            }
            Toggle("Shrink to fit", isOn: $draft.autoShrink)
            if draft.autoShrink {
                SliderRow("Minimum scale", value: $draft.minimumScale, range: 0.1...1, step: 0.05, unit: "×")
            }
            FillEditor(title: "Color", fill: $draft.textFill, automaticLabel: "Automatic (primary)")
            SliderRow("Opacity", value: $draft.textOpacity, range: 0...1, step: 0.05, unit: "")
        }
    }

    private var layoutSection: some View {
        Section("Layout") {
            OptionPicker("Horizontal alignment", selection: $draft.horizontalAlignment, style: .segmented)
            OptionPicker("Vertical alignment", selection: $draft.verticalAlignment, style: .segmented)
            SliderRow("Extra padding", value: $draft.contentPadding, range: 0...48, step: 1, unit: "pt")
            SliderRow("Rotation", value: $draft.rotation, range: -180...180, step: 1, unit: "°")
        }
    }

    private var shadowSection: some View {
        Section("Shadow") {
            Toggle("Text shadow", isOn: $draft.hasShadow)
            if draft.hasShadow {
                ColorPicker("Shadow color", selection: Binding(
                    get: { draft.shadowColor.color },
                    set: { draft.shadowColor = RGBAColor($0) }
                ))
                SliderRow("Blur", value: $draft.shadowRadius, range: 0...30, step: 1, unit: "pt")
                SliderRow("Offset X", value: $draft.shadowX, range: -20...20, step: 1, unit: "pt")
                SliderRow("Offset Y", value: $draft.shadowY, range: -20...20, step: 1, unit: "pt")
            }
        }
    }

    private var lockScreenSection: some View {
        Section {
            SliderRow("Rectangular size", value: $draft.lockRectangularSize, range: 8...80, step: 1, unit: "pt")
            SliderRow("Circular size", value: $draft.lockCircularSize, range: 8...40, step: 1, unit: "pt")
            Stepper(value: $draft.lockLineLimit, in: 0...6) {
                LabeledContent("Line limit", value: draft.lockLineLimit == 0 ? "Unlimited" : "\(draft.lockLineLimit)")
            }
            Toggle("Shrink to fit", isOn: $draft.lockShrinks)
            if draft.lockShrinks {
                SliderRow("Minimum scale", value: $draft.lockMinimumScale, range: 0.1...1, step: 0.05, unit: "×")
            }
        } header: {
            Text("Lock Screen")
        } footer: {
            Text("Used by the Lock Screen widgets. Other style settings, such as font and color, still apply.")
        }
    }

    private var backgroundSection: some View {
        Section("Background") {
            FillEditor(title: "Fill", fill: $draft.background, automaticLabel: "Automatic (system)")
        }
    }
}

// MARK: - Reusable controls

private struct OptionPicker<Option: OptionEnum>: View {
    enum Style { case menu, segmented }

    let title: String
    @Binding var selection: Option
    var style: Style = .menu

    init(_ title: String, selection: Binding<Option>, style: Style = .menu) {
        self.title = title
        _selection = selection
        self.style = style
    }

    var body: some View {
        if style == .segmented {
            VStack(alignment: .leading) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Picker(title, selection: $selection) { options }
                    .pickerStyle(.segmented)
                    .labelsHidden()
            }
        } else {
            Picker(title, selection: $selection) { options }
        }
    }

    private var options: some View {
        ForEach(Array(Option.allCases)) { Text($0.label).tag($0) }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.unit = unit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title, value: "\(value.formatted(.number.precision(.fractionLength(0...2)))) \(unit)")
            Slider(value: $value, in: range, step: step)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FillEditor: View {
    let title: String
    @Binding var fill: FillSpec
    let automaticLabel: String

    var body: some View {
        Picker(title, selection: $fill.kind) {
            ForEach(FillKind.allCases) { kind in
                Text(kind == .automatic ? automaticLabel : kind.label).tag(kind)
            }
        }

        switch fill.kind {
        case .automatic:
            EmptyView()
        case .solid:
            colorPicker("Color", index: 0)
        case .linear:
            colorPicker("Start color", index: 0)
            colorPicker("End color", index: 1)
            SliderRow("Angle", value: $fill.angle, range: 0...360, step: 1, unit: "°")
        case .radial:
            colorPicker("Center color", index: 0)
            colorPicker("Outer color", index: 1)
        case .mesh:
            colorPicker("Top leading", index: 0)
            colorPicker("Top trailing", index: 1)
            colorPicker("Bottom leading", index: 2)
            colorPicker("Bottom trailing", index: 3)
        }
    }

    private func colorPicker(_ label: String, index: Int) -> some View {
        ColorPicker(label, selection: Binding(
            get: { fill.colors[index].color },
            set: { fill.colors[index] = RGBAColor($0) }
        ))
    }
}

private struct FontFamilyPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var families: [String] {
        let all = UIFont.familyNames.sorted()
        return query.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(families, id: \.self) { family in
            Button {
                selection = family
                dismiss()
            } label: {
                HStack {
                    Text(family)
                        .font(.custom(family, size: 18))
                        .foregroundStyle(.primary)
                    Spacer()
                    if family == selection { Image(systemName: "checkmark").foregroundStyle(.tint) }
                }
            }
        }
        .searchable(text: $query)
        .navigationTitle("Font Family")
        .navigationBarTitleDisplayMode(.inline)
    }
}
