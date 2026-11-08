import SwiftUI

struct ContentView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Texts", systemImage: "text.quote") { TextsView() }
            Tab("Styles", systemImage: "paintpalette") { ProfilesView() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refresh() }
        }
    }
}

#Preview {
    ContentView()
        .environment(LibraryStore())
}
